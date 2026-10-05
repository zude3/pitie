import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/transaction_model.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static const _databaseName = 'pitie.db';
  static const _databaseVersion = 5;
  Database? _database;

  Future<Database> initDatabase() async {
    if (_database != null) return _database!;
    final databasePath = await getDatabasesPath();
    _database = await openDatabase(
      join(databasePath, _databaseName),
      version: _databaseVersion,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            description TEXT,
            date TEXT NOT NULL,
            created_at TEXT,
            account TEXT NOT NULL DEFAULT 'main',
            debt_id INTEGER,
            savings_goal_id INTEGER
          )
        ''');
        await _createDebtTable(database);
        await _createSavingsTable(database);
        await _createFinancialActivityTable(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createDebtTable(database);
          await _createSavingsTable(database);
        }
        if (oldVersion >= 2 && oldVersion < 3) {
          await database.execute('ALTER TABLE debts ADD COLUMN due_date TEXT');
          await database.execute('ALTER TABLE debts ADD COLUMN paid_at TEXT');
        }
        if (oldVersion < 3) {
          await _createFinancialActivityTable(database);
          await database.execute('''
            INSERT INTO financial_activities (kind, amount, title, date)
            SELECT 'debt_repayment', amount, recipient, COALESCE(paid_at, date)
            FROM debts WHERE is_paid = 1
          ''');
        }
        if (oldVersion < 4) {
          await _ensureColumn(
            database,
            'transactions',
            'account',
            "TEXT NOT NULL DEFAULT 'main'",
          );
          await _ensureColumn(
            database,
            'debts',
            'type',
            "TEXT NOT NULL DEFAULT 'hutang'",
          );
          await _migrateLegacyFinancialEntries(database);
        }
        if (oldVersion < 5) {
          await _ensureColumn(
            database,
            'transactions',
            'debt_id',
            'INTEGER',
          );
          await _ensureColumn(
            database,
            'transactions',
            'savings_goal_id',
            'INTEGER',
          );
          await _linkLegacyTransactions(database);
        }
      },
    );
    return _database!;
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    _validateTransaction(transaction, requireId: false);
    final database = await initDatabase();
    final id = await database.insert('transactions', transaction.toMap());
    transaction.id = id;
    return id;
  }

  Future<List<TransactionModel>> getTransactions() async {
    final database = await initDatabase();
    final rows = await database.query(
      'transactions',
      orderBy: 'date DESC, created_at DESC, id DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<TransactionModel?> getTransactionById(int id) async {
    final database = await initDatabase();
    final rows = await database.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : TransactionModel.fromMap(rows.first);
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    _validateTransaction(transaction, requireId: true);
    final database = await initDatabase();
    return database.update(
      'transactions',
      transaction.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final database = await initDatabase();
    return database.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllTransactions() async {
    final database = await initDatabase();
    return database.delete('transactions');
  }

  Future<void> _createDebtTable(Database database) async {
    await database.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        recipient TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        is_paid INTEGER NOT NULL DEFAULT 0,
        due_date TEXT,
            paid_at TEXT,
            type TEXT NOT NULL DEFAULT 'debt'
      )
    ''');
  }

  Future<void> _createSavingsTable(Database database) async {
    await database.execute('''
      CREATE TABLE savings_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createFinancialActivityTable(Database database) async {
    await database.execute('''
      CREATE TABLE financial_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL,
        amount REAL NOT NULL,
        title TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureColumn(
    DatabaseExecutor database,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await database.rawQuery('PRAGMA table_info($table)');
    if (columns.any((entry) => entry['name'] == column)) return;
    await database.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> _migrateLegacyFinancialEntries(Database database) async {
    final debts = await database.query('debts');
    for (final debt in debts) {
      await database.update(
        'debts',
        {'type': 'receivable'},
        where: 'id = ?',
        whereArgs: [debt['id']],
      );
      await database.insert('transactions', {
        'type': 'expense',
        'amount': debt['amount'],
        'category': 'Piutang',
        'description': 'Piutang: ${debt['recipient']}',
        'date': debt['date'],
        'account': 'main',
      });
      if (debt['is_paid'] == 1) {
        await database.insert('transactions', {
          'type': 'income',
          'amount': debt['amount'],
          'category': 'Pelunasan piutang',
          'description': 'Pelunasan piutang: ${debt['recipient']}',
          'date': debt['paid_at'] ?? debt['date'],
          'account': 'main',
        });
      }
    }

    final activities = await database.query(
      'financial_activities',
      where: 'kind = ?',
      whereArgs: ['savings_deposit'],
    );
    var migratedDeposits = 0.0;
    for (final activity in activities) {
      final amount = (activity['amount'] as num).toDouble();
      migratedDeposits += amount;
      await database.insert('transactions', {
        'type': 'expense',
        'amount': amount,
        'category': 'Tabungan',
        'description': 'Setoran tabungan: ${activity['title']}',
        'date': activity['date'],
        'account': 'main',
      });
    }

    final goals = await database.query('savings_goals');
    final totalSaved = goals.fold<double>(
      0,
      (sum, goal) => sum + (goal['saved_amount'] as num).toDouble(),
    );
    final unloggedSavings = totalSaved - migratedDeposits;
    if (unloggedSavings > 0) {
      await database.insert('transactions', {
        'type': 'expense',
        'amount': unloggedSavings,
        'category': 'Tabungan',
        'description': 'Saldo tabungan sebelumnya',
        'date': DateTime.now().toIso8601String(),
        'account': 'main',
      });
    }
  }

  Future<void> _linkLegacyTransactions(Database database) async {
    final debts = await database.query('debts');
    for (final debt in debts) {
      final debtId = debt['id'] as int;
      final recipient = debt['recipient'] as String;
      final type = debt['type'] as String? ?? 'debt';
      final openingDescription = switch (type) {
        'loan' => 'Pinjaman: $recipient',
        'receivable' => 'Piutang: $recipient',
        _ => null,
      };
      if (openingDescription != null) {
        await database.update(
          'transactions',
          {'debt_id': debtId},
          where: 'description = ? AND date = ? AND debt_id IS NULL',
          whereArgs: [openingDescription, debt['date']],
        );
      }
      if (debt['is_paid'] == 1) {
        final repaymentDescription = switch (type) {
          'loan' => 'Pelunasan pinjaman: $recipient',
          'receivable' => 'Pelunasan piutang: $recipient',
          _ => 'Pelunasan hutang: $recipient',
        };
        await database.update(
          'transactions',
          {'debt_id': debtId},
          where: 'description = ? AND debt_id IS NULL',
          whereArgs: [repaymentDescription],
        );
      }
    }

    final goals = await database.query('savings_goals');
    for (final goal in goals) {
      await database.update(
        'transactions',
        {'savings_goal_id': goal['id']},
        where: 'description = ? AND account = ? AND savings_goal_id IS NULL',
        whereArgs: ['Setoran tabungan: ${goal['name']}', 'main'],
      );
    }
  }

  Future<int> insertDebt(
    Map<String, Object?> debt, {
    Map<String, Object?>? openingTransaction,
  }) async {
    final database = await initDatabase();
    return database.transaction((transaction) async {
      final id = await transaction.insert('debts', debt);
      if (openingTransaction != null) {
        openingTransaction['debt_id'] = id;
        await transaction.insert('transactions', openingTransaction);
      }
      return id;
    });
  }

  Future<List<Map<String, Object?>>> getDebts() async {
    final database = await initDatabase();
    return database.query('debts', orderBy: 'date DESC, id DESC');
  }

  Future<bool> repayDebt(int id, DateTime paidAt) async {
    final database = await initDatabase();
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'debts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty || rows.first['is_paid'] == 1) return false;
      final debt = rows.first;
      await transaction.update(
        'debts',
        {'is_paid': 1, 'paid_at': paidAt.toIso8601String()},
        where: 'id = ? AND is_paid = 0',
        whereArgs: [id],
      );
      await transaction.insert('financial_activities', {
        'kind': 'debt_repayment',
        'amount': debt['amount'],
        'title': debt['recipient'],
        'date': paidAt.toIso8601String(),
      });
      final debtType = debt['type'] as String? ?? 'debt';
      final isIncome = debtType == 'receivable';
      final category = switch (debtType) {
        'loan' => 'Pelunasan pinjaman',
        'receivable' => 'Pelunasan piutang',
        _ => 'Pelunasan hutang',
      };
      await transaction.insert('transactions', {
        'type': isIncome ? 'income' : 'expense',
        'amount': debt['amount'],
        'category': category,
        'description': '$category: ${debt['recipient']}',
        'date': paidAt.toIso8601String(),
        'account': 'main',
        'debt_id': id,
      });
      return true;
    });
  }

  Future<List<Map<String, Object?>>> getFinancialActivities() async {
    final database = await initDatabase();
    return database.query(
      'financial_activities',
      orderBy: 'date DESC, id DESC',
    );
  }

  Future<void> recordSavingsDeposit(
    int goalId,
    double amount,
    DateTime date,
  ) async {
    final database = await initDatabase();
    await database.transaction((transaction) async {
      final rows = await transaction.query(
        'savings_goals',
        where: 'id = ?',
        whereArgs: [goalId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Savings goal not found.');
      final goal = rows.first;
      final savedAmount = (goal['saved_amount'] as num).toDouble() + amount;
      await transaction.update(
        'savings_goals',
        {'saved_amount': savedAmount},
        where: 'id = ?',
        whereArgs: [goalId],
      );
      await transaction.insert('financial_activities', {
        'kind': 'savings_deposit',
        'amount': amount,
        'title': goal['name'],
        'date': date.toIso8601String(),
      });
      await transaction.insert('transactions', {
        'type': 'expense',
        'amount': amount,
        'category': 'Tabungan',
        'description': 'Setoran tabungan: ${goal['name']}',
        'date': date.toIso8601String(),
        'account': 'main',
        'savings_goal_id': goalId,
      });
    });
  }

  Future<void> recordSavingsUse(
    int goalId,
    double amount,
    String purpose,
    DateTime date,
  ) async {
    final database = await initDatabase();
    await database.transaction((transaction) async {
      final rows = await transaction.query(
        'savings_goals',
        where: 'id = ?',
        whereArgs: [goalId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Savings goal not found.');
      final goal = rows.first;
      final currentAmount = (goal['saved_amount'] as num).toDouble();
      if (amount > currentAmount) {
        throw StateError('Savings balance is insufficient.');
      }
      await transaction.update(
        'savings_goals',
        {'saved_amount': currentAmount - amount},
        where: 'id = ?',
        whereArgs: [goalId],
      );
      await transaction.insert('financial_activities', {
        'kind': 'savings_use',
        'amount': amount,
        'title': purpose,
        'date': date.toIso8601String(),
      });
      await transaction.insert('transactions', {
        'type': 'expense',
        'amount': amount,
        'category': 'Penggunaan tabungan',
        'description': purpose,
        'date': date.toIso8601String(),
        'account': 'savings',
        'savings_goal_id': goalId,
      });
    });
  }

  Future<int> clearDebts() async {
    final database = await initDatabase();
    return database.transaction((transaction) async {
      await transaction.delete(
        'transactions',
        where: 'debt_id IS NOT NULL',
      );
      return transaction.delete('debts');
    });
  }

  Future<int> insertSavingsGoal(Map<String, Object?> goal) async {
    final database = await initDatabase();
    return database.insert('savings_goals', goal);
  }

  Future<List<Map<String, Object?>>> getSavingsGoals() async {
    final database = await initDatabase();
    return database.query('savings_goals', orderBy: 'created_at DESC, id DESC');
  }

  void _validateTransaction(
    TransactionModel transaction, {
    required bool requireId,
  }) {
    if (requireId && transaction.id == null) {
      throw ArgumentError('Transaction id is required for update.');
    }
    if (!const ['income', 'expense'].contains(transaction.type.name)) {
      throw ArgumentError('Transaction type is invalid.');
    }
    if (!transaction.amount.isFinite || transaction.amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero.');
    }
    if (transaction.category.trim().isEmpty) {
      throw ArgumentError('Transaction category is required.');
    }
  }
}

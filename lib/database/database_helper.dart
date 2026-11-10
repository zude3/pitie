import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/debt_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static const _databaseName = 'pitie.db';
  static const _databaseVersion = 6;
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
            savings_goal_id INTEGER,
            financial_activity_id INTEGER
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
          await _ensureColumn(database, 'transactions', 'debt_id', 'INTEGER');
          await _ensureColumn(
            database,
            'transactions',
            'savings_goal_id',
            'INTEGER',
          );
          await _linkLegacyTransactions(database);
        }
        if (oldVersion < 6) {
          await _ensureColumn(
            database,
            'transactions',
            'financial_activity_id',
            'INTEGER',
          );
          await _ensureColumn(
            database,
            'financial_activities',
            'debt_id',
            'INTEGER',
          );
          await _ensureColumn(
            database,
            'financial_activities',
            'savings_goal_id',
            'INTEGER',
          );
          await _ensureColumn(
            database,
            'financial_activities',
            'transaction_id',
            'INTEGER',
          );
        }
      },
    );
    return _database!;
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    _validateTransaction(transaction, requireId: false);
    final database = await initDatabase();
    final id = await database.insert('transactions', transaction.toLegacyMap());
    transaction.id = id.toString();
    return id;
  }

  Future<List<TransactionModel>> getTransactions() async {
    final database = await initDatabase();
    final rows = await database.query(
      'transactions',
      orderBy: 'date DESC, created_at DESC, id DESC',
    );
    return rows.map(TransactionModel.fromLegacyMap).toList();
  }

  Future<TransactionModel?> getTransactionById(int id) async {
    final database = await initDatabase();
    final rows = await database.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : TransactionModel.fromLegacyMap(rows.first);
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    _validateTransaction(transaction, requireId: true);
    final database = await initDatabase();
    return database.update(
      'transactions',
      transaction.toLegacyMap()..remove('id'),
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
        date TEXT NOT NULL,
        debt_id INTEGER,
        savings_goal_id INTEGER,
        transaction_id INTEGER
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
        await _linkFirstDebtTransaction(
          database,
          debtId,
          openingDescription,
          debt['date'] as String,
        );
      }
      if (debt['is_paid'] == 1) {
        final repaymentDescription = switch (type) {
          'loan' => 'Pelunasan pinjaman: $recipient',
          'receivable' => 'Pelunasan piutang: $recipient',
          _ => 'Pelunasan hutang: $recipient',
        };
        await _linkFirstDebtTransaction(
          database,
          debtId,
          repaymentDescription,
          debt['paid_at'] as String? ?? debt['date'] as String,
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

  Future<void> _linkFirstDebtTransaction(
    DatabaseExecutor database,
    int debtId,
    String description,
    String date,
  ) async {
    final rows = await database.query(
      'transactions',
      columns: ['id'],
      where: 'description = ? AND date = ? AND debt_id IS NULL',
      whereArgs: [description, date],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return;
    await database.update(
      'transactions',
      {'debt_id': debtId},
      where: 'id = ?',
      whereArgs: [rows.first['id']],
    );
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

  Future<void> updateDebt(DebtModel debt) async {
    final id = int.parse(debt.id!);
    final database = await initDatabase();
    await database.transaction((transaction) async {
      final debtRows = await transaction.query(
        'debts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (debtRows.isEmpty) throw StateError('Debt not found.');
      final linkedTransactions = await transaction.query(
        'transactions',
        where: 'debt_id = ?',
        whereArgs: [id],
      );
      final openings = linkedTransactions
          .where(
            (row) =>
                !(row['category'] as String? ?? '').startsWith('Pelunasan '),
          )
          .toList();
      final repayments = linkedTransactions
          .where(
            (row) =>
                (row['category'] as String? ?? '').startsWith('Pelunasan '),
          )
          .toList();
      await transaction.update(
        'debts',
        debt.toLegacyMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [id],
      );

      final openingType = switch (debt.type) {
        DebtType.loan => TransactionType.income,
        DebtType.receivable => TransactionType.expense,
        DebtType.debt => null,
      };
      if (openingType == null) {
        await transaction.delete(
          'transactions',
          where: "debt_id = ? AND category NOT LIKE 'Pelunasan %'",
          whereArgs: [id],
        );
      } else {
        final opening = TransactionModel(
          id: openings.isEmpty ? null : openings.first['id'].toString(),
          type: openingType,
          amount: debt.amount,
          category: debt.type == DebtType.loan ? 'Pinjaman' : 'Piutang',
          description: '${debt.type.label}: ${debt.recipient}',
          date: debt.date,
          debtId: id.toString(),
        );
        if (openings.isEmpty) {
          await transaction.insert('transactions', opening.toLegacyMap());
        } else {
          await transaction.update(
            'transactions',
            opening.toLegacyMap()..remove('id'),
            where: 'id = ?',
            whereArgs: [openings.first['id']],
          );
          for (final duplicate in openings.skip(1)) {
            await transaction.delete(
              'transactions',
              where: 'id = ?',
              whereArgs: [duplicate['id']],
            );
          }
        }
      }

      final repaymentType = debt.type == DebtType.receivable
          ? TransactionType.income
          : TransactionType.expense;
      final repaymentCategory = switch (debt.type) {
        DebtType.loan => 'Pelunasan pinjaman',
        DebtType.receivable => 'Pelunasan piutang',
        DebtType.debt => 'Pelunasan hutang',
      };
      for (final row in repayments) {
        final current = TransactionModel.fromLegacyMap(row);
        final activityId = await _activityIdForTransaction(
          transaction,
          row,
          kind: 'debt_repayment',
          legacyTitle: current.description.split(':').skip(1).join(':').trim(),
        );
        await transaction.update(
          'transactions',
          {
            'type': repaymentType.name,
            'amount': debt.amount,
            'category': repaymentCategory,
            'description': '$repaymentCategory: ${debt.recipient}',
            'financial_activity_id': ?activityId,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        if (activityId != null) {
          await transaction.update(
            'financial_activities',
            {
              'amount': debt.amount,
              'title': debt.recipient,
              'debt_id': id,
              'transaction_id': row['id'],
            },
            where: 'id = ?',
            whereArgs: [activityId],
          );
        }
      }
    });
  }

  Future<void> deleteDebt(int id) async {
    final database = await initDatabase();
    await database.transaction((transaction) async {
      final debtRows = await transaction.query(
        'debts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (debtRows.isEmpty) throw StateError('Debt not found.');
      final linkedTransactions = await transaction.query(
        'transactions',
        where: 'debt_id = ?',
        whereArgs: [id],
      );
      for (final row in linkedTransactions) {
        if ((row['category'] as String? ?? '').startsWith('Pelunasan ')) {
          final current = TransactionModel.fromLegacyMap(row);
          final activityId = await _activityIdForTransaction(
            transaction,
            row,
            kind: 'debt_repayment',
            legacyTitle: current.description
                .split(':')
                .skip(1)
                .join(':')
                .trim(),
          );
          if (activityId != null) {
            await transaction.delete(
              'financial_activities',
              where: 'id = ?',
              whereArgs: [activityId],
            );
          }
        }
      }
      await transaction.delete(
        'transactions',
        where: 'debt_id = ?',
        whereArgs: [id],
      );
      await transaction.delete('debts', where: 'id = ?', whereArgs: [id]);
    });
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
      final activityId = await transaction.insert('financial_activities', {
        'kind': 'debt_repayment',
        'amount': debt['amount'],
        'title': debt['recipient'],
        'date': paidAt.toIso8601String(),
        'debt_id': id,
      });
      final debtType = debt['type'] as String? ?? 'debt';
      final isIncome = debtType == 'receivable';
      final category = switch (debtType) {
        'loan' => 'Pelunasan pinjaman',
        'receivable' => 'Pelunasan piutang',
        _ => 'Pelunasan hutang',
      };
      final transactionId = await transaction.insert('transactions', {
        'type': isIncome ? 'income' : 'expense',
        'amount': debt['amount'],
        'category': category,
        'description': '$category: ${debt['recipient']}',
        'date': paidAt.toIso8601String(),
        'account': 'main',
        'debt_id': id,
        'financial_activity_id': activityId,
      });
      await transaction.update(
        'financial_activities',
        {'transaction_id': transactionId},
        where: 'id = ?',
        whereArgs: [activityId],
      );
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

  Future<void> updateSavingsGoal(SavingsGoalModel goal) async {
    final id = int.parse(goal.id!);
    final database = await initDatabase();
    final updated = await database.update(
      'savings_goals',
      {'name': goal.name, 'target_amount': goal.targetAmount},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) throw StateError('Savings goal not found.');
  }

  Future<void> deleteSavingsGoal(int id) async {
    final database = await initDatabase();
    await database.transaction((transaction) async {
      final rows = await transaction.query(
        'savings_goals',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Savings goal not found.');
      final goal = rows.first;
      final savedAmount = (goal['saved_amount'] as num).toDouble();
      if (savedAmount > 0) {
        await transaction.insert('transactions', {
          'type': 'income',
          'amount': savedAmount,
          'category': 'Tabungan',
          'description': 'Pengembalian tabungan: ${goal['name']}',
          'date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'account': 'main',
        });
      }
      await transaction.delete(
        'savings_goals',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
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
      final activityId = await transaction.insert('financial_activities', {
        'kind': 'savings_deposit',
        'amount': amount,
        'title': goal['name'],
        'date': date.toIso8601String(),
        'savings_goal_id': goalId,
      });
      final transactionId = await transaction.insert('transactions', {
        'type': 'expense',
        'amount': amount,
        'category': 'Tabungan',
        'description': 'Setoran tabungan: ${goal['name']}',
        'date': date.toIso8601String(),
        'account': 'main',
        'savings_goal_id': goalId,
        'financial_activity_id': activityId,
      });
      await transaction.update(
        'financial_activities',
        {'transaction_id': transactionId},
        where: 'id = ?',
        whereArgs: [activityId],
      );
    });
  }

  Future<void> recordSavingsUse(
    int goalId,
    double amount,
    String category,
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
      final activityId = await transaction.insert('financial_activities', {
        'kind': 'savings_use',
        'amount': amount,
        'title': category,
        'date': date.toIso8601String(),
        'savings_goal_id': goalId,
      });
      final transactionId = await transaction.insert('transactions', {
        'type': 'expense',
        'amount': amount,
        'category': category,
        'description': 'Pemakaian tabungan: $category',
        'date': date.toIso8601String(),
        'account': 'savings',
        'savings_goal_id': goalId,
        'financial_activity_id': activityId,
      });
      await transaction.update(
        'financial_activities',
        {'transaction_id': transactionId},
        where: 'id = ?',
        whereArgs: [activityId],
      );
    });
  }

  Future<void> updateSavingsActivity(TransactionModel updated) async {
    final transactionId = int.parse(updated.id!);
    final database = await initDatabase();
    await database.transaction((transaction) async {
      final rows = await transaction.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Savings transaction not found.');
      final currentRow = rows.first;
      final current = TransactionModel.fromLegacyMap(currentRow);
      final goalIdValue = current.savingsGoalId;
      if (goalIdValue == null) {
        throw StateError('Savings goal reference is missing.');
      }
      final goalId = int.parse(goalIdValue);
      final goals = await transaction.query(
        'savings_goals',
        where: 'id = ?',
        whereArgs: [goalId],
        limit: 1,
      );
      if (goals.isEmpty) throw StateError('Savings goal not found.');
      final goal = goals.first;
      final savedAmount = (goal['saved_amount'] as num).toDouble();
      final isDeposit = current.account == TransactionAccount.main;
      if (current.type != TransactionType.expense ||
          (!isDeposit && current.account != TransactionAccount.savings) ||
          (isDeposit && current.category != 'Tabungan')) {
        throw StateError('Linked transaction is not a savings activity.');
      }
      final difference = updated.amount - current.amount;
      final updatedSavedAmount = isDeposit
          ? savedAmount + difference
          : savedAmount - difference;
      if (updatedSavedAmount < 0) {
        throw StateError('Savings balance is insufficient.');
      }
      final activityId = await _activityIdForTransaction(
        transaction,
        currentRow,
        kind: isDeposit ? 'savings_deposit' : 'savings_use',
        legacyTitle: isDeposit
            ? current.description.replaceFirst('Setoran tabungan: ', '')
            : current.category,
      );
      final normalized = TransactionModel(
        id: current.id,
        type: TransactionType.expense,
        amount: updated.amount,
        category: isDeposit ? 'Tabungan' : updated.category.trim(),
        description: isDeposit
            ? current.description
            : 'Pemakaian tabungan: ${updated.category.trim()}',
        date: updated.date,
        createdAt: current.createdAt,
        account: current.account,
        savingsGoalId: goalId.toString(),
        financialActivityId: activityId?.toString(),
      );
      _validateTransaction(normalized, requireId: true);
      await transaction.update(
        'savings_goals',
        {'saved_amount': updatedSavedAmount},
        where: 'id = ?',
        whereArgs: [goalId],
      );
      await transaction.update(
        'transactions',
        normalized.toLegacyMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      if (activityId != null) {
        await transaction.update(
          'financial_activities',
          {
            'amount': normalized.amount,
            'title': isDeposit ? goal['name'] : normalized.category,
            'date': normalized.date.toIso8601String(),
            'savings_goal_id': goalId,
            'transaction_id': transactionId,
          },
          where: 'id = ?',
          whereArgs: [activityId],
        );
      }
    });
  }

  Future<void> deleteSavingsActivity(int transactionId) async {
    final database = await initDatabase();
    await database.transaction((transaction) async {
      final rows = await transaction.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Savings transaction not found.');
      final currentRow = rows.first;
      final current = TransactionModel.fromLegacyMap(currentRow);
      final goalIdValue = current.savingsGoalId;
      if (goalIdValue == null) {
        throw StateError('Savings goal reference is missing.');
      }
      final goalId = int.parse(goalIdValue);
      final goals = await transaction.query(
        'savings_goals',
        where: 'id = ?',
        whereArgs: [goalId],
        limit: 1,
      );
      if (goals.isEmpty) throw StateError('Savings goal not found.');
      final savedAmount = (goals.first['saved_amount'] as num).toDouble();
      final isDeposit = current.account == TransactionAccount.main;
      if (current.type != TransactionType.expense ||
          (!isDeposit && current.account != TransactionAccount.savings) ||
          (isDeposit && current.category != 'Tabungan')) {
        throw StateError('Linked transaction is not a savings activity.');
      }
      final updatedSavedAmount = isDeposit
          ? savedAmount - current.amount
          : savedAmount + current.amount;
      if (updatedSavedAmount < 0) {
        throw StateError('Savings balance is insufficient.');
      }
      final activityId = await _activityIdForTransaction(
        transaction,
        currentRow,
        kind: isDeposit ? 'savings_deposit' : 'savings_use',
        legacyTitle: isDeposit
            ? current.description.replaceFirst('Setoran tabungan: ', '')
            : current.category,
      );
      await transaction.update(
        'savings_goals',
        {'saved_amount': updatedSavedAmount},
        where: 'id = ?',
        whereArgs: [goalId],
      );
      if (activityId != null) {
        await transaction.delete(
          'financial_activities',
          where: 'id = ?',
          whereArgs: [activityId],
        );
      }
      await transaction.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
  }

  Future<int> clearDebts() async {
    final database = await initDatabase();
    return database.transaction((transaction) async {
      await transaction.delete(
        'transactions',
        where: 'debt_id IN (SELECT id FROM debts)',
      );
      await transaction.delete(
        'financial_activities',
        where: 'kind = ?',
        whereArgs: ['debt_repayment'],
      );
      return transaction.delete('debts');
    });
  }

  Future<int> insertSavingsGoal(Map<String, Object?> goal) async {
    final database = await initDatabase();
    return database.insert('savings_goals', goal);
  }

  Future<int?> _activityIdForTransaction(
    DatabaseExecutor executor,
    Map<String, Object?> transaction, {
    required String kind,
    String? legacyTitle,
  }) async {
    final activityId = transaction['financial_activity_id'];
    if (activityId is num) return activityId.toInt();
    final transactionId = transaction['id'];
    if (transactionId is num) {
      final linked = await executor.query(
        'financial_activities',
        columns: ['id'],
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (linked.isNotEmpty) return linked.first['id'] as int;
    }

    final title =
        legacyTitle ??
        switch (kind) {
          'debt_repayment' =>
            (transaction['description'] as String? ?? '')
                .split(':')
                .skip(1)
                .join(':')
                .trim(),
          'savings_deposit' =>
            (transaction['description'] as String? ?? '').replaceFirst(
              'Setoran tabungan: ',
              '',
            ),
          _ => transaction['category'] as String? ?? '',
        };
    final transactionDate = DateTime.parse(transaction['date'] as String);
    final candidates =
        (await executor.query(
          'financial_activities',
          where: 'kind = ?',
          whereArgs: [kind],
        )).where((activity) {
          return (activity['amount'] as num).toDouble() ==
                  (transaction['amount'] as num).toDouble() &&
              activity['title'] == title &&
              DateTime.parse(activity['date'] as String)
                  .isAtSameMomentAs(transactionDate);
        }).toList();
    if (candidates.length > 1) {
      throw StateError(
        'Multiple legacy financial activities match this transaction.',
      );
    }
    return candidates.isEmpty ? null : candidates.single['id'] as int;
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

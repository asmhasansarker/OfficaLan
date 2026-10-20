import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/message_model.dart';
import '../models/peer_model.dart';

class StorageService {
  static Database? _database;
  static const String _dbName = 'officelan_vault.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            sender_id TEXT NOT NULL,
            recipient_id TEXT NOT NULL,
            type TEXT NOT NULL,
            content TEXT NOT NULL,
            file_name TEXT,
            file_size INTEGER,
            mime_type TEXT,
            timestamp INTEGER NOT NULL,
            status TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE peers (
            id TEXT PRIMARY KEY,
            displayName TEXT NOT NULL,
            department TEXT NOT NULL,
            ip TEXT NOT NULL,
            port INTEGER NOT NULL,
            status TEXT NOT NULL,
            lastSeen INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE call_logs (
            id TEXT PRIMARY KEY,
            peer_id TEXT NOT NULL,
            peer_name TEXT NOT NULL,
            direction TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            duration_seconds INTEGER NOT NULL,
            status TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> saveMessage(MessageModel message) async {
    final db = await database;
    await db.insert('messages', message.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MessageModel>> getConversation(String peerA, String peerB) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: '(sender_id = ? AND recipient_id = ?) OR (sender_id = ? AND recipient_id = ?)',
      whereArgs: [peerA, peerB, peerB, peerA],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => MessageModel.fromMap(map)).toList();
  }
}
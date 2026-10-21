import sqlite3

conn = sqlite3.connect(r'C:\Users\tbaltzakis\AppData\Roaming\Devin\cli\sessions.db')
c = conn.cursor()

# List tables
c.execute('SELECT name FROM sqlite_master WHERE type="table"')
tables = c.fetchall()
print("Tables:", tables)

# For each table, show schema and sample data
for table in tables:
    table_name = table[0]
    print(f"\n=== Table: {table_name} ===")
    c.execute('PRAGMA table_info(?)', (table_name,))
    cols = c.fetchall()
    print("Columns:", cols)
    c.execute('SELECT * FROM ? LIMIT 5', (table_name,))
    rows = c.fetchall()
    for row in rows:
        print(row)

conn.close()
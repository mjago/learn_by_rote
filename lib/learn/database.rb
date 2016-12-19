class Database

  DATABASE_NAME = 'test.sqlite'
  USE_MEMORY = false

  # Open a database

  def initialize
    open_db
  end

  # Create a database

  def db_exists?
    File.exist?(DATABASE_NAME)
  end

  def open_db
    create = !db_exists?
    create ||= USE_MEMORY
    @db = SQLite3::Database.new ":memory:" if USE_MEMORY
    @db = SQLite3::Database.new DATABASE_NAME unless USE_MEMORY
    db_create if create
    db_initialize if create
  end

  def sql_questions_table
    <<-SQL
        create table questions (
            catagory_id int,
            question varchar(255),
            answer varchar(255),
            interval integer,
            easiness real,
            next_date text
        );
SQL
  end

  def sql_catagories_table
    <<-SQL
        create table catagories (
               id int,
               catagory varchar(255)
        );
SQL
  end

  def db_create
    @db.execute sql_questions_table
    @db.execute sql_catagories_table
  end

  def get_catagory_id
    @db.execute("select id from catagories where catagory is \"bluetooth\"").first[0].to_s
  end

  def write_score(id, interval, easiness, next_date)
    @db.execute("UPDATE questions SET interval = #{interval}, easiness = #{easiness}, next_date = \"#{next_date.to_s}\" WHERE rowid = #{id}")
  end

  def write_question(cat, qu, ans)
    id = @db.last_insert_row_id
    @db.execute("insert into questions VALUES (\"#{cat}\", \"#{qu}\", \"#{ans}\", NULL, NULL, NULL)")
  end

  def read_questions(id = :any)
    return_val = []
    if id == :any
      id = @db.execute('select * from catagories')[0][0]
    end
    @db.execute("select rowid, * from questions where catagory_id is \"#{id}\"" ) do |row|
      return_val << {id: row[0], cat: row[1], qu: row[2], ans: row[3], interval: row[4], easiness: row[5], next_date: row[6]}
    end
    return_val
  end

  def read_catagories
    return_val = []
    @db.execute('select * from catagories') do |row|
      return_val << {id: row[0], catagory: row[1]}
    end
    return_val
  end

  def close
    @db.close
  end

  def db_initialize
    @db.execute "INSERT INTO catagories VALUES(\"1\", \"bluetooth\")"
  end
end

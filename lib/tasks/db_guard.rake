# DB は abr-batch と共用しているので、DB やテーブルを作り直すタスクは実行できないようにする
# （db:drop で abr の DB が消える、db:schema:load でテーブルが空になる、などを防ぐ）
GUARDED_DB_TASKS = %w[
  db:create db:create:all db:drop db:drop:all db:drop:_unsafe db:purge db:purge:all
  db:migrate db:migrate:up db:migrate:down db:migrate:redo db:migrate:reset db:rollback
  db:reset db:setup db:prepare db:seed db:seed:replant db:truncate_all
  db:schema:load db:schema:dump db:test:prepare db:test:load db:test:load_schema db:test:purge
].freeze

GUARDED_DB_TASKS.each do |name|
  next unless Rake::Task.task_defined?(name)

  Rake::Task[name].clear
  task name do
    abort "#{name} は実行できません。DB は abr-batch と共用しています（lib/tasks/db_guard.rake）"
  end
end

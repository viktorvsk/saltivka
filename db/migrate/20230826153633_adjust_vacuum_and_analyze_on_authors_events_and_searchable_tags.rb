class AdjustVacuumAndAnalyzeOnAuthorsEventsAndSearchableTags < ActiveRecord::Migration[7.0]
  def up
    connection.execute("ALTER TABLE events SET (autovacuum_vacuum_scale_factor = 0.0)")
    connection.execute("ALTER TABLE events SET (autovacuum_vacuum_threshold = 10000)")
    connection.execute("ALTER TABLE events SET (autovacuum_analyze_scale_factor = 0.0)")
    connection.execute("ALTER TABLE events SET (autovacuum_analyze_threshold = 10000)")

    connection.execute("ALTER TABLE authors SET (autovacuum_vacuum_scale_factor = 0.0)")
    connection.execute("ALTER TABLE authors SET (autovacuum_vacuum_threshold = 1000)")
    connection.execute("ALTER TABLE authors SET (autovacuum_analyze_scale_factor = 0.0)")
    connection.execute("ALTER TABLE authors SET (autovacuum_analyze_threshold = 1000)")

    connection.execute("ALTER TABLE searchable_tags SET (autovacuum_vacuum_scale_factor = 0.0)")
    connection.execute("ALTER TABLE searchable_tags SET (autovacuum_vacuum_threshold = 10000)")
    connection.execute("ALTER TABLE searchable_tags SET (autovacuum_analyze_scale_factor = 0.0)")
    connection.execute("ALTER TABLE searchable_tags SET (autovacuum_analyze_threshold = 10000)")
  end

  def down
    connection.execute("ALTER TABLE events RESET (autovacuum_vacuum_scale_factor)")
    connection.execute("ALTER TABLE events RESET (autovacuum_vacuum_threshold)")
    connection.execute("ALTER TABLE events RESET (autovacuum_analyze_scale_factor)")
    connection.execute("ALTER TABLE events RESET (autovacuum_analyze_threshold)")

    connection.execute("ALTER TABLE authors RESET (autovacuum_vacuum_scale_factor)")
    connection.execute("ALTER TABLE authors RESET (autovacuum_vacuum_threshold)")
    connection.execute("ALTER TABLE authors RESET (autovacuum_analyze_scale_factor)")
    connection.execute("ALTER TABLE authors RESET (autovacuum_analyze_threshold)")

    connection.execute("ALTER TABLE searchable_tags RESET (autovacuum_vacuum_scale_factor)")
    connection.execute("ALTER TABLE searchable_tags RESET (autovacuum_vacuum_threshold)")
    connection.execute("ALTER TABLE searchable_tags RESET (autovacuum_analyze_scale_factor)")
    connection.execute("ALTER TABLE searchable_tags RESET (autovacuum_analyze_threshold)")
  end
end

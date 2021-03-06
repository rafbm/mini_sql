require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg'
  gem 'mini_sql', path: '../'
  gem 'activesupport'
  gem 'activerecord'
  gem 'activemodel'
  gem 'memory_profiler'
  gem 'benchmark-ips'
  gem 'sequel'
  gem 'sequel_pg', require: 'sequel'
end

require 'sequel'
require 'active_record'
require 'memory_profiler'
require 'benchmark/ips'
require 'mini_sql'

ActiveRecord::Base.establish_connection(
  :adapter => "postgresql",
  :database => "test_db"
)

DB = Sequel.postgres('test_db')

pg = ActiveRecord::Base.connection.raw_connection

pg.async_exec <<SQL
drop table if exists topics
SQL

pg.async_exec <<SQL
CREATE TABLE topics (
    id integer NOT NULL PRIMARY KEY,
    title character varying NOT NULL,
    last_posted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    views integer DEFAULT 0 NOT NULL,
    posts_count integer DEFAULT 0 NOT NULL,
    user_id integer,
    last_post_user_id integer NOT NULL,
    reply_count integer DEFAULT 0 NOT NULL,
    featured_user1_id integer,
    featured_user2_id integer,
    featured_user3_id integer,
    avg_time integer,
    deleted_at timestamp without time zone,
    highest_post_number integer DEFAULT 0 NOT NULL,
    image_url character varying,
    like_count integer DEFAULT 0 NOT NULL,
    incoming_link_count integer DEFAULT 0 NOT NULL,
    category_id integer,
    visible boolean DEFAULT true NOT NULL,
    moderator_posts_count integer DEFAULT 0 NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    bumped_at timestamp without time zone NOT NULL,
    has_summary boolean DEFAULT false NOT NULL,
    vote_count integer DEFAULT 0 NOT NULL,
    archetype character varying DEFAULT 'regular'::character varying NOT NULL,
    featured_user4_id integer,
    notify_moderators_count integer DEFAULT 0 NOT NULL,
    spam_count integer DEFAULT 0 NOT NULL,
    pinned_at timestamp without time zone,
    score double precision,
    percent_rank double precision DEFAULT 1.0 NOT NULL,
    subtype character varying,
    slug character varying,
    deleted_by_id integer,
    participant_count integer DEFAULT 1,
    word_count integer,
    excerpt character varying(1000),
    pinned_globally boolean DEFAULT false NOT NULL,
    pinned_until timestamp without time zone,
    fancy_title character varying(400),
    highest_staff_post_number integer DEFAULT 0 NOT NULL,
    featured_link character varying
)
SQL

class Topic < ActiveRecord::Base
end

class TopicSequel < Sequel::Model(:topics)
end


Topic.transaction do
  topic = {
  }
  Topic.columns.each do |c|
    topic[c.name.to_sym] = case c.type
                           when :integer then 1
                           when :datetime then Time.now
                           when :boolean then false
                           else "HELLO WORLD" * 2
                           end
  end

  1000.times do |id|
    topic[:id] = id
    Topic.create!(topic)
  end
end

$conn = ActiveRecord::Base.connection.raw_connection

def ar_title_id_pluck
  s = +""
  Topic.limit(1000).order(:id).pluck(:id, :title).each do |id, title|
    s << id.to_s
    s << title
  end
  s
end

def ar_title_id
  s = +""
  Topic.limit(1000).order(:id).select(:id, :title).each do |t|
    s << t.id.to_s
    s << t.title
  end
  s
end

def pg_title_id
  s = +""
  # use the safe pattern here
  r = $conn.async_exec(-"select id, title from topics order by id limit 1000")
  r.each do |row|
    s << row["id"].to_s
    s << row["title"]
  end
  r.clear
  s
end

$mini_sql = MiniSql::Connection.new($conn)

def mini_sql_title_id
  s = +""
  $mini_sql.query(-"select id, title from topics order by id limit 1000").each do |t|
    s << t.id.to_s
    s << t.title
  end
  s
end

def sequel_select_title_id
  s = +""
  TopicSequel.limit(1000).order(:id).select(:id, :title).each do |t|
    s << t.id.to_s
    s << t.title
  end
  s
end

def sequel_pluck_title_id
  s = +""
  TopicSequel.limit(1000).order(:id).select_map([:id, :title]).each do |t|
    s << t[0].to_s
    s << t[1]
  end
  s
end

# usage is not really recommended but just to compare to pluck lets have it
def mini_sql_title_id_query_single
  s = +""
  i = 0
  r = $mini_sql.query_single(-"select id, title from topics order by id limit 1000")
  while i < r.length
    s << r[i].to_s
    s << r[i+1]
    i += 2
  end
  s
end

results = [
  ar_title_id,
  ar_title_id_pluck,
  pg_title_id,
  mini_sql_title_id,
  sequel_pluck_title_id,
  sequel_select_title_id,
  mini_sql_title_id_query_single
]

exit(-1) unless results.uniq.length == 1


def wide_topic_ar
  Topic.first
end

def wide_topic_pg
  r = $conn.async_exec("select * from topics limit 1")
  row = r.first
  r.clear
  row
end

def wide_topic_sequel
  TopicSequel.first
end

def wide_topic_mini_sql
  $conn.query("select * from topics limit 1").first
end

Benchmark.ips do |r|
  r.report("wide topic ar") do |n|
    while n > 0
      wide_topic_ar
      n -= 1
    end
  end
  r.report("wide topic sequel") do |n|
    while n > 0
      wide_topic_sequel
      n -= 1
    end
  end
  r.report("wide topic pg") do |n|
    while n > 0
      wide_topic_pg
      n -= 1
    end
  end
  r.report("wide topic mini sql") do |n|
    while n > 0
      wide_topic_mini_sql
      n -= 1
    end
  end
  r.compare!
end



Benchmark.ips do |r|
  r.report("ar select title id") do |n|
    while n > 0
      ar_title_id
      n -= 1
    end
  end
  r.report("ar select title id pluck") do |n|
    while n > 0
      ar_title_id_pluck
      n -= 1
    end
  end
  r.report("sequel title id select") do |n|
    while n > 0
      sequel_select_title_id
      n -= 1
    end
  end
  r.report("pg select title id") do |n|
    while n > 0
      pg_title_id
      n -= 1
    end
  end
  r.report("mini_sql select title id") do |n|
    while n > 0
      mini_sql_title_id
      n -= 1
    end
  end
  r.report("sequel title id pluck") do |n|
    while n > 0
      sequel_pluck_title_id
      n -= 1
    end
  end
  r.report("mini_sql query_single title id") do |n|
    while n > 0
      mini_sql_title_id_query_single
      n -= 1
    end
  end
  r.compare!
end


# Calculating -------------------------------------
#        wide topic ar      2.383k (± 4.9%) i/s -     12.005k in   5.050490s
#    wide topic sequel      3.449k (± 3.2%) i/s -     17.591k in   5.104951s
#        wide topic pg      7.345k (± 1.2%) i/s -     37.352k in   5.086015s
#  wide topic mini sql      7.536k (± 1.4%) i/s -     38.220k in   5.072834s
#
# Comparison:
#  wide topic mini sql:     7535.8 i/s
#        wide topic pg:     7345.1 i/s - same-ish: difference falls within error
#    wide topic sequel:     3449.4 i/s - 2.18x  slower
#        wide topic ar:     2382.9 i/s - 3.16x  slower
#
# Calculating -------------------------------------
#   ar select title id    131.572  (± 3.8%) i/s -    658.000  in   5.008231s
# ar select title id pluck
#                         696.233  (± 3.7%) i/s -      3.519k in   5.061335s
# sequel title id select
#                         916.841  (± 3.7%) i/s -      4.655k in   5.084499s
#   pg select title id      1.002k (± 4.0%) i/s -      5.044k in   5.040584s
# mini_sql select title id
#                           1.106k (± 2.4%) i/s -      5.618k in   5.084423s
# sequel title id pluck
#                           1.181k (± 3.5%) i/s -      5.980k in   5.069815s
# mini_sql query_single title id
#                           1.171k (± 3.1%) i/s -      5.880k in   5.025793s
#
# Comparison:
# sequel title id pluck:     1181.0 i/s
# mini_sql query_single title id:     1171.1 i/s - same-ish: difference falls within error
# mini_sql select title id:     1105.6 i/s - 1.07x  slower
#   pg select title id:     1002.2 i/s - 1.18x  slower
# sequel title id select:      916.8 i/s - 1.29x  slower
# ar select title id pluck:      696.2 i/s - 1.70x  slower
#   ar select title id:      131.6 i/s - 8.98x  slower
#

# to run deep analysis run
# MemoryProfiler.report do
#   ar
# end.pretty_print


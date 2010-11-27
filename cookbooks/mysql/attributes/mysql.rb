mysql_path "/db/mysql" unless attribute?("mysql_path")

set.mysql_options unless attribute?("mysql_options")
mysql_options.innodb_buffer_pool_size '630M' unless mysql_options.attribute?("innodb_buffer_pool_size")
mysql_options.max_connections '300' unless mysql_options.attribute?("max_connections")
mysql_options.query_cache_limit '1M' unless mysql_options.attribute?("query_cache_limit")
mysql_options.query_cache_size '16M' unless mysql_options.attribute?("query_cache_size")
mysql_options.table_cache '1024' unless mysql_options.attribute?("table_cache")


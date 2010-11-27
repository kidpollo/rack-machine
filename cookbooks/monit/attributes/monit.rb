
set.monit unless attribute?('monit')

# General
monit.run_every                 '200'   unless monit.attribute? 'run_every'
monit.recipients                 []     unless monit.attribute? 'recipients'

# Server
monit.http_user                 'monit' unless monit.attribute? 'http_user'
monit.http_pass                 'pass'  unless monit.attribute? 'http_pass'

# Memory
monit.small_load_avg_time       '1min'  unless monit.attribute? 'load_avg_time'
monit.big_load_avg_time         '5min'  unless monit.attribute? 'load_avg_time'
monit.small_load_avg_level      4       unless monit.attribute? 'load_avg_time'
monit.big_load_avg_level        2       unless monit.attribute? 'load_avg_time'
monit.general_memory_usage      '75%'   unless monit.attribute? 'general_memory_usage'

# Cpu
monit.cpu_usage_user            '70%'   unless monit.attribute? 'cpu_usage_user'
monit.cpu_usage_system          '30%'   unless monit.attribute? 'cpu_usage_system'
monit.cpu_usage_wait            '30%'   unless monit.attribute? 'cpu_usage_wait'


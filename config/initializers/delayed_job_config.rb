Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.sleep_delay = Rails.env.development? ? 5 : 3
Delayed::Worker.max_attempts = 3
Delayed::Worker.max_run_time = 15.minutes
Delayed::Worker.read_ahead = 5
Delayed::Worker.delay_jobs = !Rails.env.test?
Delayed::Worker.default_queue_name = 'default'
Delayed::Worker.raise_signal_exceptions = :term
# so that worker unlocks the job upon SIGTERM so that another worker will pick it up later (heroku)
Delayed::Worker.logger = Logger.new(STDOUT)

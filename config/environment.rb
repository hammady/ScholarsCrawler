# Load the rails application
require File.expand_path('../application', __FILE__)

ENV['WRITABLE_DIR'] = Rails.root.join('writable').to_s

# Initialize the rails application
QcriScholars::Application.initialize!

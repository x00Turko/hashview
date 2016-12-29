require 'rubygems'
require 'data_mapper'
require 'bcrypt'

# read config
options = YAML.load_file('config/database.yml')

# there has to be a better way to handle this shit
if ENV['RACK_ENV'] == 'test'
  DataMapper::Logger.new($stdout, :debug)
  DataMapper.setup(:default, options['test'])
elsif ENV['RACK_ENV'] == 'development'
  DataMapper::Logger.new($stdout, :debug)
  DataMapper.setup(:default, options['development'])
elsif ENV['RACK_ENV'] == ('production' || 'default')
  DataMapper.setup(:default, options['production'])
else
  puts 'ERROR: You must define an evironment. ex: RACK_ENV=production'
  exit
end

# User class object to handle user account credentials
class User
  include DataMapper::Resource

  property :id, Serial
  property :username, String, key: true, length: (3..40), required: true
  property :hashed_password, String, length: 128
  property :admin, Boolean
  property :created_at, DateTime, default: DateTime.now
  property :phone, String, required: false
  property :email, String, required: false

  attr_accessor :password
  validates_presence_of :username

  def password=(pass)
    @password = pass
    self.hashed_password = User.encrypt(@password)
  end

  def self.encrypt(pass)
    BCrypt::Password.create(pass)
  end

  def self.authenticate(username, pass)
    user = User.first(username: username)
    if user
      return user.username if BCrypt::Password.new(user.hashed_password) == pass
    end
  end

  def self.create_test_user(attrs = {})
    user = User.new(
      username: 'test',
      admin: true,
      hashed_password: BCrypt::Password.create('omgplains')
    )
    user.save
    user.update(attrs) if attrs
    user.save
    return user.id
  end

  def self.delete_test_user(id)
    user = User.first(id: id)
    user.destroy
  end

  def self.delete_all_users()
    @users = User.all
    @users.destroy
  end

end

# Class to handle authenticated sessions
class Sessions
  include DataMapper::Resource

  property :id, Serial
  property :session_key, String, length: 128
  property :username, String, length: (3..40), required: true

  def self.isValid?(session_key)
    sessions = Sessions.first(session_key: session_key)

    return true if sessions
  end

  def self.type(session_key)
    sess = Sessions.first(session_key: session_key)

    if sess
      if User.first(username: sess.username).admin
        return TRUE
      else
        return FALSE
      end
    end
  end

  def self.getUsername(session_key)
    sess = Sessions.first(session_key: session_key)

    return sess.username if sess
  end
end

# Each Customer record will be stored here
class Customers
  include DataMapper::Resource
  property :id, Serial
  property :name, String, length: 40
  property :description, String, length: 500
end

# Each job generated by user will be stored here
class Jobs
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :last_updated_by, String, length: 40
  property :updated_at, DateTime, default: DateTime.now
  # status options should be "Running", "Paused", "Completed", "Queued", "Canceled", "Ready"
  property :status, String, length: 100
  property :targettype, String, length: 2000
  property :hashfile_id, Integer
  property :policy_min_pass_length, Integer
  property :policy_complexity_default, Boolean
  property :customer_id, Integer
  property :notify_completed, Boolean
end

# Jobs will have multiple crack tasks
class Jobtasks
  include DataMapper::Resource

  property :id, Serial
  property :job_id, Integer
  property :task_id, Integer
  property :build_cmd, String, length: 5000
  # status options should be "Running", "Paused", "Not Started", "Completed", "Queued", "Failed", "Canceled", "Importing"
  property :status, String
  property :run_time, Integer
end

# Task definitions
class Tasks
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :source, String
  property :mask, String
  property :command, String, length: 4000
  property :wl_id, String, length: 256
  property :hc_attackmode, String, length: 25
  property :hc_rule, String
  property :hc_mask, String
end

# Table for handle the storage of uncracked/cracked hashes per job
class Targets
  include DataMapper::Resource

  property :id, Serial
  property :username, String, length: 2000
  property :originalhash, String, length: 4000
  property :hashtype, Integer
  property :cracked, Boolean
  property :plaintext, String, length: 2000
  property :hashfile_id, Integer
  property :customer_id, Integer
end

# Table for handling hashes cracked and uncracked
class Hashes
  include DataMapper::Resource

  property :id, Serial
  property :originalhash, String, length: 255, :unique_index => true
  property :hashtype, Integer, :index => true
  property :cracked, Boolean
  property :plaintext, String, length: 256
  #belongs_to :Hashfilehashes
  #has n, :hashfilehashs, 'Hashfilehash'
  #  :child_key => 'hashes_id' # We add the second 's because...bugs?
end

# Table for managing association between users and hashes
class Hashfilehashes
  include DataMapper::Resource

  property :id, 	Serial
  property :hash_id, 	Integer
  property :username, 	String, length: 2000
  property :hashfile_id, Integer, :index => true
  #belongs_to :hashes, :key => true #'Hashes'#,
  #  parent_key: ['id']
end

# User Settings
class Settings
  include DataMapper::Resource

  property :id, Serial
  property :hcbinpath, String, length: 2000
  property :hcglobalopts, String, length: 2000
  property :maxtasktime, String, length: 2000
  property :maxjobtime, String, length: 2000
  property :smtp_server, String
  property :smtp_user, String
  property :smtp_pass, String
  property :smtp_use_tls, Boolean
  property :smtp_auth_type, String # Options are plain, login, cram_md5, none
  property :clientmode, Boolean
end

# Wordlist Class
class Wordlists
  include DataMapper::Resource

  property :id, Serial
  property :name, String, length: 256
  property :path, String, length: 2000
  property :size, Integer
end

# Hashfile Class
class Hashfiles
  include DataMapper::Resource

  property :id, Serial
  property :customer_id, Integer
  property :name, String, length: 256
  property :hash_str, String, length: 256
  property :total_run_time, Integer, default: 0
end

DataMapper.finalize

ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define(:version => 0) do
  create_table :books do |t|
    t.integer :custom_remote_id
  end

  create_table :users do |t|
    t.integer :remote_id
    t.string  :email
  end

  create_table :products do |t|
    t.integer :remote_id
  end

  create_table :has_remote_synchronizations do |t|
    t.string   :model_name, :null => false
    t.datetime :last_record_updated_at, :null => false
    t.integer  :last_record_id, :null => false
    t.datetime :created_at
  end

  create_table :cheeses do |t|
    t.string  :name
    t.integer :maturity, :default => 5
    t.integer :smell
    t.integer :remote_id
  end
end
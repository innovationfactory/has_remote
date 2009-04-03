ActiveRecord::Schema.define(:version => 0) do
  create_table :books do |t|
    t.integer :remote_id
  end
  
  create_table :users do |t|
    t.integer :remote_id
  end

  create_table :has_remote_synchronizations do |t|
    t.string :model_name, :null => false
    t.datetime :latest_change, :null => false
    t.datetime :created_at
  end
end
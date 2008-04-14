class CreateSchema < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string :identity_url
      t.string :salt, :limit => 40
      t.string :remember_token
      t.timestamp :remember_token_expires_at
      t.timestamps
    end
    
    create_table :open_id_authentication_associations, :force => true do |t|
      t.integer :issued, :lifetime
      t.string :handle, :assoc_type
      t.binary :server_url, :secret
    end

    create_table :open_id_authentication_nonces, :force => true do |t|
      t.integer :timestamp, :null => false
      t.string :server_url, :null => true
      t.string :salt, :null => false
    end

    create_table :client_applications do |t|
      t.string :name
      t.string :url
      t.string :support_url
      t.string :callback_url
      t.string :key, :limit => 50
      t.string :secret, :limit => 50
      t.integer :user_id
      t.timestamps
    end
    add_index :client_applications, :key, :unique
    
    create_table :oauth_tokens do |t|
      t.integer :user_id
      t.string :type, :limit => 20
      t.integer :client_application_id
      t.string :token, :limit => 50
      t.string :secret, :limit => 50
      t.timestamp :authorized_at, :invalidated_at
      t.timestamps
    end
    
    add_index :oauth_tokens, :token, :unique
    
    create_table :oauth_nonces do |t|
      t.string :nonce
      t.integer :timestamp
      t.timestamps
    end
    add_index :oauth_nonces, [:nonce, :timestamp], :unique
  end
  
  def self.down
    drop_table :client_applications
    drop_table :oauth_tokens
    drop_table :oauth_nonces
    drop_table :open_id_authentication_associations
    drop_table :open_id_authentication_nonces
    drop_table :users
  end
end
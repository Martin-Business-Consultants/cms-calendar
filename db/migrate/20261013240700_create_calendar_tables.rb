# frozen_string_literal: true

# The content calendar: the social channels connected (their tokens
# encrypted), the items planned (a social post, a post or page on the site,
# a note), and each item's delivery to each channel with what came of it.
class CreateCalendarTables < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_channels do |t|
      t.string :network, null: false
      t.string :name, null: false
      t.string :handle
      t.string :external_id, null: false
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.string :state, null: false, default: "connected"
      t.text :error
      t.references :connected_by, foreign_key: {to_table: :users, on_delete: :nullify}
      t.timestamps
    end
    add_index :calendar_channels, [:network, :external_id], unique: true

    create_table :calendar_items do |t|
      t.string :title, null: false
      t.string :kind, null: false, default: "social"
      t.string :state, null: false, default: "idea"
      t.datetime :scheduled_at
      t.text :body
      t.string :link_url
      t.bigint :asset_id
      t.string :subject_type
      t.bigint :subject_id
      t.string :source
      t.text :notes
      t.string :draft_state
      t.text :draft_error
      t.references :user, foreign_key: {on_delete: :nullify}
      t.timestamps
    end
    add_index :calendar_items, :scheduled_at
    add_index :calendar_items, [:state, :scheduled_at]
    add_index :calendar_items, :source

    create_table :calendar_deliveries do |t|
      t.references :item, null: false, foreign_key: {to_table: :calendar_items, on_delete: :cascade}
      t.references :channel, null: false, foreign_key: {to_table: :calendar_channels, on_delete: :cascade}
      t.text :text
      t.string :state, null: false, default: "pending"
      t.string :external_id
      t.string :external_url
      t.text :error
      t.integer :attempts, null: false, default: 0
      t.datetime :sent_at
      t.timestamps
    end
    add_index :calendar_deliveries, [:item_id, :channel_id], unique: true
  end
end

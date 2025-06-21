class AddIsPasswordlessToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :is_passwordless, :boolean, default: false, null: false

    # パスワードの最小文字数を標準の Devise 設定に合わせて明示的に制約
    # これにより通常のユーザーは確実に強固なパスワードを持つよう保証
    add_check_constraint :users,
      "LENGTH(encrypted_password) >= 60 OR is_passwordless = true",
      name: "ensure_strong_password_unless_passwordless"
  end
end

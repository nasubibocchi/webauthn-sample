class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  has_one :webauthn_user, dependent: :destroy
  delegate :passkeys, to: :webauthn_user, allow_nil: true
  
  # パスワードレス登録を可能にする
  attr_accessor :passwordless
  
  # パスワードレス登録かどうかを判定するフラグと登録方法を保存
  after_create :mark_passwordless_user, if: -> { passwordless }
  
  # パスワードレス登録の場合のみパスワードチェックをスキップ
  # 通常のユーザー登録では標準のパスワードバリデーションを適用
  def password_required?
    return false if passwordless
    super
  end
  
  # このユーザーがパスキー専用ユーザーかどうかを確認
  def passwordless_user?
    # パスキーが登録されており、かつ is_passwordless フラグが true
    passkeys.exists? && self[:is_passwordless] 
  end
  
  private
  
  # パスワードレスユーザーとしてマークする
  def mark_passwordless_user
    update_column(:is_passwordless, true)
  end
end

Rails.application.routes.draw do
  # 一覧（検索・ページャー）
  root "rsdts#index"
  # 編集・更新・削除。:id は主キー 5 列を "_" でつないだもの（例：/rsdt/131016_0001001_006_001_/edit）
  resources :rsdts, path: "rsdt", only: %i[edit update destroy]

  get "up" => "rails/health#show", as: :rails_health_check
end

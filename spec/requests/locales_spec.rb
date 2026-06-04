require "rails_helper"

RSpec.describe "Locales", type: :request do
  describe "default locale" do
    it "renders the app in brazilian portuguese by default" do
      get new_session_path

      expect(response.body).to include('<html lang="pt-BR">')
      expect(response.body).to include("Entrar")
    end
  end

  describe "PATCH /locale" do
    it "persists the selected locale on the signed-in user account" do
      user = create(:user)
      sign_in(user)

      patch locale_path, params: { locale: "en", redirect_path: bands_path }

      expect(response).to redirect_to(bands_path)
      expect(user.reload.locale).to eq("en")
    end

    it "uses the signed-in user's persisted locale on later requests" do
      user = create(:user, locale: "en")
      sign_in(user)

      get bands_path

      expect(response.body).to include("Language")
    end
  end
end

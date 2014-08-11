module TestEngine
  class ApplicationController < ActionController::Base
    def test_engine
      render :text => "test engine"
    end
  end
end

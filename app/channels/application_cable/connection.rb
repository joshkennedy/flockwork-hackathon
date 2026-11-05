module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_session

    def connect
      set_current_person || reject_unauthorized_connection
    end

    def current_person = current_session.person

    private
      def set_current_person
        self.current_session = Session.find_by(id: cookies.signed[:session_id])
      end
  end
end

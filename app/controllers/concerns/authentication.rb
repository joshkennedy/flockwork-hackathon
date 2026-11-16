module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      if cookies.signed[:demo_session]
        clear_demo_cookies
        redirect_to new_demo_session_path, notice: "The demo reset. Choose a role to keep exploring."
      else
        redirect_to root_path
      end
    end

    def start_new_session_for(person, auth_method:, verified_email: nil)
      person.with_lock do
        raise ActiveRecord::RecordNotFound unless person.active?

        find_session_by_cookie&.destroy
        person.update_column(:last_signed_in_at, Time.current)
        person.sessions.create!(auth_method:, verified_email:, user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
          Current.session = session
          cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax, secure: Rails.env.production? }
          if person.organization.demo?
            cookies.signed[:demo_session] = demo_cookie
          else
            cookies.delete(:demo_session)
            cookies.delete(:demo_public)
          end
        end
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
      clear_demo_cookies
    end

    def remember_demo_public_visit(organization)
      if organization.demo?
        cookies.signed[:demo_public] = demo_cookie
      else
        cookies.delete(:demo_public)
      end
    end

    def recover_demo_public_reset(error)
      raise error unless cookies.signed[:demo_public]

      clear_demo_cookies
      redirect_to new_demo_session_path, notice: "The demo reset. Choose a role to keep exploring."
    end

    def demo_cookie
      { value: true, expires: 2.hours.from_now, httponly: true, same_site: :lax, secure: Rails.env.production? }
    end

    def clear_demo_cookies
      cookies.delete(:session_id)
      cookies.delete(:demo_session)
      cookies.delete(:demo_public)
    end
end

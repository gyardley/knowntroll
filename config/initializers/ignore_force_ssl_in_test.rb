module ActionController
  module ForceSSL
    module ClassMethods
      alias_method :original_force_ssl, :force_ssl

      def force_ssl(options = {})
        unless Rails.env.test? || Rails.env.development?
          original_force_ssl
        end
      end
    end
  end
end
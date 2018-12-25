module Iamspec::Helpers
  class Stscache
    require 'singleton'
    include Singleton

    def initialize
      @stscache ||= {}
    end

    def get_or_create_sts_for_role(role)
      @sts ||= Aws::STS::Client.new()
      @stscache[role] ||= @sts.assume_role(role_arn: role, role_session_name: 'temp')
      if @stscache[role].credentials.expiration < Time.now+600
        @stscache[role] = @sts.assume_role(role_arn: role, role_session_name: 'temp')
      end
      @stscache[role]
    end
  end
end

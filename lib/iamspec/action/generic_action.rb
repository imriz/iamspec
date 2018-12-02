module Iamspec::Action
  def perform_action(action_name, resource_arns = [])
    GenericAction.new([action_name], nil, resource_arns)
  end

  def perform_action_with_caller_arn(action_name, caller_arn, resource_arns = [])
    GenericAction.new([action_name], caller_arn, resource_arns)
  end

  def perform_actions(action_names, resource_arns = [])
    GenericAction.new(action_names, nil, resource_arns)
  end

  class GenericAction
    attr_reader :action_names
    attr_reader :caller_arn
    attr_reader :resource_arns
    attr_reader :creds
    attr_reader :policy_string
    attr_reader :policy
    attr_reader :userid
    attr_reader :sourcevpce
    attr_reader :sourceip
    attr_reader :context_entries

    def initialize(action_names, caller_arn = nil, resource_arns)
      @caller_arn = caller_arn
      @action_names = action_names
      @resource_arns = resource_arns
      @context_entries = {}
    end

    def to_s
      if @resource_arns.empty?
        action_names.join(',')
      else
        "#{action_names.join(',')} on #{resource_arns.join(',')}"
      end
    end

    def with_credentials(creds)
      @creds = creds
      self
    end

    def with_resource(resource_arn)
      @resource_arns = [resource_arn]
      self
    end

    def with_policy_from_user_name(user_name, assume_role_arn = nil)
      opts = {}
      if assume_role_arn
        @sts ||= Aws::STS::Client.new()
        opts[:credentials] = @sts.assume_role(role_arn: assume_role_arn, role_session_name: 'temp')
      end
      iam = Aws::IAM::Client.new(opts)
      policies = []
      iam.list_user_policies(user_name: user_name).policy_names.each do |policy|
        policies << iam.get_user_policy(user_name: user_name, policy_name: policy).policy_document
      end
      iam.list_attached_user_policies(user_name: user_name).attached_policies.each do |attached_policy|
        policy = iam.get_policy(policy_arn: attached_policy.policy_arn).policy
        policies << URI.decode_www_form_component(iam.get_policy_version(policy_arn: policy.arn, version_id: policy.default_version_id).policy_version.document)
      end
      with_policy(policies)
    end

    def with_policy(policy)
      @policy = policy
      self
    end

    def with_caller_arn(caller_arn)
      @caller_arn = caller_arn
      self
    end

    def with_caller_arn_from_role_name(role_arn, assume_role_arn = nil)
      opts = {}
      if assume_role_arn
        @sts ||= Aws::STS::Client.new()
        opts[:credentials] = @sts.assume_role(role_arn: assume_role_arn, role_session_name: 'temp')
      end
      iam = Aws::IAM::Client.new(opts)
      with_caller_arn(iam.get_role(role_name: role_arn).role.arn)
    end


    def with_source_arn_from_role_name(role_arn, assume_role_arn = nil)
      opts = {}
      if assume_role_arn
        @sts ||= Aws::STS::Client.new()
        opts[:credentials] = @sts.assume_role(role_arn: assume_role_arn, role_session_name: 'temp')
      end
      iam = Aws::IAM::Client.new(opts)
      with_source_arn(iam.get_role(role_name: role_arn).role.arn)
    end

    def with_source_arn(arn)
      @context_entries[:source_arn] = Aws::IAM::Types::ContextEntry.new({context_key_name: "AWS:SourceArn", context_key_values: [arn], context_key_type: "string"})
      self
    end

    def with_userid_from_user_arn(user_arn, assume_role_arn = nil)
      opts = {}
      if assume_role_arn
        @sts ||= Aws::STS::Client.new()
        opts[:credentials] = @sts.assume_role(role_arn: assume_role_arn, role_session_name: 'temp')
      end
      iam = Aws::IAM::Client.new(opts)
      @userid = iam.get_user(user_name: user_arn).user.user_id
      @context_entries[:userid] = Aws::IAM::Types::ContextEntry.new({context_key_name: "aws:userid", context_key_values: ["#{@userid}"], context_key_type: "string"})
      self
    end

    def with_userid_from_role_arn(role_arn, assume_role_arn = nil)
      opts = {}
      if assume_role_arn
        @sts ||= Aws::STS::Client.new()
        opts[:credentials] = @sts.assume_role(role_arn: assume_role_arn, role_session_name: 'temp')
      end
      iam = Aws::IAM::Client.new(opts)
      @userid = iam.get_role(role_name: role_arn).role.role_id
      @context_entries[:userid] = Aws::IAM::Types::ContextEntry.new({context_key_name: "aws:userid", context_key_values: ["#{@userid}:#{role_arn}"], context_key_type: "string"})
      self
    end

    def with_userid(userid)
      @userid = userid
      @context_entries[:userid] = Aws::IAM::Types::ContextEntry.new({context_key_name: "aws:userid", context_key_values: [userid], context_key_type: "string"})
      self
    end

    def with_sourcevpce(sourcevpce)
      @sourcevpce = sourcevpce
      @context_entries[:sourcevpce] = Aws::IAM::Types::ContextEntry.new({context_key_name: "aws:sourceVpce", context_key_values: [sourcevpce], context_key_type: "string"})
      self
    end

    def with_sourceip(sourceip)
      @sourceip = sourceip
      @context_entries[:sourceip] = Aws::IAM::Types::ContextEntry.new({context_key_name: "aws:SourceIp", context_key_values: [sourceip], context_key_type: "string"})
      self
    end

    def add_context(context_key_name, context_key_values, context_key_type="string")
      @context_entries[context_key_name.to_sym] = Aws::IAM::Types::ContextEntry.new({context_key_name: context_key_name, context_key_values: (context_key_values.is_a? Array ? context_key_values : [context_key_values]), context_key_type: context_key_type})
      self
    end

    def with_resource_policy(role_arn = nil, resource_arns = @resource_arns)
      @sts ||= Aws::STS::Client.new()
      res = @sts.assume_role(role_arn: role_arn, role_session_name: 'temp')
      resource_arns.each do |arn|
        if arn.start_with?('arn:aws:s3:::')
          bucket = arn.scan(/arn:aws:s3:::([^\/]+)/).last.first
          s3 = Aws::S3::Client.new(:credentials => res)
          @policy_string = s3.get_bucket_policy(:bucket => bucket).policy.read
        elsif arn.start_with?('arn:aws:sqs:')
          queue_parts = arn.scan(/arn:aws:sqs:([^\:]+):([^\:]+):([^\:]+)/).last
          queue_url = URI.encode("https://sqs.#{queue_parts[0]}.amazonaws.com/#{queue_parts[1]}/#{queue_parts[2]}")
          sqs = Aws::SQS::Client.new(:credentials => res)
          @policy_string = sqs.get_queue_attributes({queue_url: queue_url, attribute_names: ["Policy"]}).attributes['Policy']
        end
      end
      self
    end
  end
end

module Iamspec::Action
  def perform_s3_action(action_name, resource_arns = [])
    S3Action.new([action_name], nil, resource_arns)
  end

  def perform_s3_action_with_caller_arn(action_name, caller_arn, resource_arns = [])
    S3Action.new([action_name], caller_arn, resource_arns)
  end

  def perform_s3_actions(action_names, resource_arns = [])
    S3Action.new(action_names, nil, resource_arns)
  end

  class S3Action < GenericAction
    attr_reader :sse_encryption_aws_kms_key_id
    attr_reader :sse

    def initialize(action_names, caller_arn, resource_arns)
      super(action_names, caller_arn, resource_arns)
    end

    def with_resource(resource_arn)
      if resource_arn.start_with?('arn:aws:s3:::') and @action_names.map(&:downcase).include?('s3:listbucket')
        path = resource_arn.split("/")
        if path.size > 1
          @context_entries[:s3_prefix] = Aws::IAM::Types::ContextEntry.new({context_key_name: "s3:prefix", context_key_values: [path.join('/')], context_key_type: "string"})
        end
        resource_arn = path.shift
      end
      @resource_arns = [resource_arn]
      self
    end

    def with_sse(sse)
      @sse = sse
      @context_entries[:sse] = Aws::IAM::Types::ContextEntry.new({context_key_name: "s3:x-amz-server-side-encryption", context_key_values: [sse], context_key_type: "string"})
      self
    end

    def with_sse_encryption_aws_kms_key_id(sse_encryption_aws_kms_key_id)
      @sse_encryption_aws_kms_key_id = sse_encryption_aws_kms_key_id
      @context_entries[:sse_encryption_aws_kms_key_id] = Aws::IAM::Types::ContextEntry.new({context_key_name: "s3:x-amz-server-side-encryption-aws-kms-key-id", context_key_values: [sse_encryption_aws_kms_key_id], context_key_type: "string"})
      self
    end

  end
end

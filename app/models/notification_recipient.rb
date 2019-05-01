# frozen_string_literal: true

class NotificationRecipient
  include Gitlab::Utils::StrongMemoize

  attr_reader :user, :type, :reason
  def initialize(user, type, **opts)
    unless NotificationSetting.levels.key?(type) || type == :subscription
      raise ArgumentError, "invalid type: #{type.inspect}"
    end

    @custom_action = opts[:custom_action]
    @acting_user = opts[:acting_user]
    @target = opts[:target]
    @project = opts[:project] || default_project
    @group = opts[:group] || @project&.group
    @user = user
    @type = type
    @reason = opts[:reason]
    @skip_read_ability = opts[:skip_read_ability]
  end

  def notification_setting
    @notification_setting ||= find_notification_setting
  end

  def notification_level
    @notification_level ||= notification_setting&.level&.to_sym
  end

  def notifiable?
    return false unless has_access?
    return false if own_activity?

    # even users with :disabled notifications receive manual subscriptions
    return !unsubscribed? if @type == :subscription

    return false unless suitable_notification_level?

    # check this last because it's expensive
    # nobody should receive notifications if they've specifically unsubscribed
    # except if they were mentioned.
    return false if @type != :mention && unsubscribed?

    true
  end

  def suitable_notification_level?
    case notification_level
    when :mention
      @type == :mention
    when :participating
      !excluded_participating_action? && %i[participating mention watch].include?(@type)
    when :custom
      custom_enabled? || %i[participating mention].include?(@type)
    when :watch
      !excluded_watcher_action?
    else
      false
    end
  end

  def custom_enabled?
    @custom_action && notification_setting&.event_enabled?(@custom_action)
  end

  def unsubscribed?
    return false unless @target
    return false unless @target.respond_to?(:subscriptions)

    subscription = @target.subscriptions.find { |subscription| subscription.user_id == @user.id }
    subscription && !subscription.subscribed
  end

  def own_activity?
    return false unless @acting_user

    if user == @acting_user
      # if activity was generated by the same user, change reason to :own_activity
      @reason = NotificationReason::OWN_ACTIVITY
      # If the user wants to be notified, we must return `false`
      !@acting_user.notified_of_own_activity?
    else
      false
    end
  end

  def has_access?
    DeclarativePolicy.subject_scope do
      break false unless user.can?(:receive_notifications)
      break true if @skip_read_ability

      break false if @target && !user.can?(:read_cross_project)
      break false if @project && !user.can?(:read_project, @project)

      break true unless read_ability
      break true unless DeclarativePolicy.has_policy?(@target)

      user.can?(read_ability, @target)
    end
  end

  def excluded_watcher_action?
    return false unless @custom_action

    NotificationSetting::EXCLUDED_WATCHER_EVENTS.include?(@custom_action)
  end

  def excluded_participating_action?
    return false unless @custom_action

    NotificationSetting::EXCLUDED_PARTICIPATING_EVENTS.include?(@custom_action)
  end

  private

  def read_ability
    return if @skip_read_ability
    return @read_ability if instance_variable_defined?(:@read_ability)

    @read_ability =
      if @target.is_a?(Ci::Pipeline)
        :read_build # We have build trace in pipeline emails
      elsif default_ability_for_target
        :"read_#{default_ability_for_target}"
      end
  end

  def default_ability_for_target
    @default_ability_for_target ||=
      if @target.respond_to?(:to_ability_name)
        @target.to_ability_name
      elsif @target.class.respond_to?(:model_name)
        @target.class.model_name.name.underscore
      end
  end

  def default_project
    return if @target.nil?
    return @target if @target.is_a?(Project)
    return @target.project if @target.respond_to?(:project)
  end

  def find_notification_setting
    project_setting = @project && user.notification_settings_for(@project)

    return project_setting unless project_setting.nil? || project_setting.global?

    group_setting = closest_non_global_group_notification_settting

    return group_setting unless group_setting.nil?

    user.global_notification_setting
  end

  # Returns the notification_setting of the lowest group in hierarchy with non global level
  def closest_non_global_group_notification_settting
    return unless @group
    return if indexed_group_notification_settings.empty?

    notification_setting = nil

    @group.self_and_ancestors_ids.each do |id|
      notification_setting = indexed_group_notification_settings[id]
      break if notification_setting
    end

    notification_setting
  end

  def indexed_group_notification_settings
    strong_memoize(:indexed_group_notification_settings) do
      @group.notification_settings.where(user_id: user.id)
        .where.not(level: NotificationSetting.levels[:global])
        .index_by(&:source_id)
    end
  end
end

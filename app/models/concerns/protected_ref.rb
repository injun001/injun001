module ProtectedRef
  extend ActiveSupport::Concern

  included do
    belongs_to :project

    validates :name, presence: true
    validates :project, presence: true

    delegate :matching, :matches?, :wildcard?, to: :ref_matcher
  end

  def commit
    project.commit(self.name)
  end

  class_methods do
    def protected_ref_access_levels(*types)
      types.each do |type|
        # We need to set `inverse_of` to make sure the `belongs_to`-object is set
        # when creating children using `accepts_nested_attributes_for`.
        #
        # If we don't `protected_branch` or `protected_tag` would be empty and
        # `project` cannot be delegated to it, which in turn would cause validations
        # to fail.
        has_many :"#{type}_access_levels", dependent: :destroy, inverse_of: self.model_name.singular # rubocop:disable Cop/ActiveRecordDependent

        validates :"#{type}_access_levels", length: { minimum: 0 }

        accepts_nested_attributes_for :"#{type}_access_levels", allow_destroy: true

        # Returns access levels that grant the specified access type to the given user / group.
        access_level_class = const_get("#{type}_access_level".classify)
        protected_type = self.model_name.singular
        scope :"#{type}_access_by_user", -> (user) { access_level_class.joins(protected_type.to_sym).where("#{protected_type}_id" => self.ids).merge(access_level_class.by_user(user)) }
        scope :"#{type}_access_by_group", -> (group) { access_level_class.joins(protected_type.to_sym).where("#{protected_type}_id" => self.ids).merge(access_level_class.by_group(group)) }
      end
    end

    def protected_ref_accessible_to?(ref, user, action:)
      access_levels_for_ref(ref, action: action).any? do |access_level|
        access_level.check_access(user)
      end
    end

    def developers_can?(action, ref)
      access_levels_for_ref(ref, action: action).any? do |access_level|
        access_level.access_level == Gitlab::Access::DEVELOPER
      end
    end

    def access_levels_for_ref(ref, action:)
      self.matching(ref).map(&:"#{action}_access_levels").flatten
    end

    def matching(ref_name, protected_refs: nil)
      ProtectedRefMatcher.matching(self, ref_name, protected_refs: protected_refs)
    end
  end

  private

  def ref_matcher
    @ref_matcher ||= ProtectedRefMatcher.new(self)
  end
end

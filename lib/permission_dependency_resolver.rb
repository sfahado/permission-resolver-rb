require 'tsort' # HINT

# A Monkey patch to sort the permissions in topological sort
class Hash
  include TSort
  alias tsort_each_node each_key
  def tsort_each_child(node, &block)
    fetch(node).each(&block)
  end
end

class PermissionDependencyResolver

  def initialize(dependencies)
    @dependencies = dependencies
  end

  def can_grant?(existing, perm_to_be_granted)
    ##
    # WIP: for complex structure,  raise Error when there will be no vertex of the edge
    # with parent or sub-parent in the dependency tree
    # unless (remaining = existing - collect_all_parent(perm_to_be_granted)).empty?
    #   if remaining.reject { |s| s.eql?('view') }.length
    #     raise InvalidBasePermissionsError
    #   end
    # end

    ##
    # when existing elements in Array has same permission which needs to be granted,
    # In that case don't iterate and return `true` from here without complex operation
    ##
    return true if existing.include? perm_to_be_granted

    ##
    # A case when we require to check the parents of all the existing Array and grant the
    # permissions that needs to be granted, iterate recursively and find the match
    ##


    required_permissions = @dependencies[perm_to_be_granted]
    return false unless required_permissions.length

    contains_permission = true
    required_permissions.each do |require_permission|
      match_in_parent_element = false
      existing.each do |e_permission|
        parents = collect_all_parent(e_permission)
        if parents.include?(require_permission)
          match_in_parent_element = true
          break
        end
      end
      contains_permission = false unless match_in_parent_element
    end
    contains_permission
  end

  ##
  # In #can_deny? We first check if there is at least one matching permission exist that needs to be
  # removed, else it's a error `InvalidBasePermissionsError`, it returns `false` for view permission
  # because it's the main condition for permission's dependencies and rest check every element in
  # the `existing` key to map to `view` permission. if yes, we can remove that key else, don't!
  ##
  def can_deny?(existing, perm_to_be_denied)
    return false if perm_to_be_denied.eql?('view')

    raise InvalidBasePermissionsError if existing.none?(perm_to_be_denied) && existing.length

    remaining_permissions = existing - [perm_to_be_denied]
    remaining_permissions.map! do |e_permission|
      collect_all_parent(e_permission).include?('view')
    end.all?
  end

  ##
  # The sort functions takes the array and create the hash, hash is then sort based on the
  # topological sort with respect to dependencies graph
  # ##
  def sort(permissions)
    permission_hash = {}
    permissions.each do |permission|
      permission_hash[permission] = @dependencies[permission]
    end
    permission_hash.tsort
  end

  ##
  # The method returns all the ancestor of a given permissions and return to the caller function.
  # it is recursively being called and return the array.
  # ##
  def collect_all_parent(permission, parent = [])
    return [permission] unless [permission].length

    @dependencies[permission].each do |gp|
      parent << (gp.instance_of?(Array) ? collect_all_parent(gp, parent).compact.flatten! : gp)
    end
    parent << permission
  end
end

module ApplicationHelper
  def pagination_params(param_name, page)
    request.query_parameters.merge(param_name => page)
  end

  def tab_params(tab_name)
    request.query_parameters.merge(tab: tab_name)
  end
end

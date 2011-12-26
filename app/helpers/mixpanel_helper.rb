module MixpanelHelper
  
  def track(name, properties={})
    if Rails.env.production?
      code = "mpq.track(#{name.to_json}, #{properties.to_json});".html_safe
      head {haml_tag('script', code)}
    end
  end
  
  def track_pageview
    if Rails.env.production?
      code = "mpq.track('page viewed', {'page name':document.title, 'url':window.location.pathname});".html_safe
      head {haml_tag('script', code)}
    end
  end
end

###
File generated by js-routes GEM_VERSION
Based on Rails RAILS_VERSION routes of APP_CLASS
###
root = (exports ? this)

ParameterMissing = (message, fileName, lineNumber) ->
  instance = new Error(message, fileName, lineNumber)
  if Object.setPrototypeOf
    Object.setPrototypeOf instance, Object.getPrototypeOf(this)
  else
    instance.__proto__ = this.__proto__
  if Error.captureStackTrace
    Error.captureStackTrace instance, ParameterMissing
  instance

ParameterMissing.prototype = Object.create(Error.prototype, constructor:
  value: Error
  enumerable: false
  writable: true
  configurable: true
)

if Object.setPrototypeOf
  Object.setPrototypeOf(ParameterMissing, Error)
else
  ParameterMissing.__proto__ = Error

NodeTypes = NODE_TYPES
DeprecatedGlobbingBehavior = DEPRECATED_GLOBBING_BEHAVIOR
SpecialOptionsKey = SPECIAL_OPTIONS_KEY
UriEncoderSegmentRegex = /[^a-zA-Z0-9\-\._~!\$&'\(\)\*\+,;=:@]/g # this is ActionDispatch::Journey::Router::Utils::UriEncoder::SEGMENT

ReservedOptions = [
  'anchor'
  'trailing_slash'
  'subdomain'
  'host'
  'port'
  'protocol'
]

Utils =

  configuration:
    prefix: PREFIX
    default_url_options: DEFAULT_URL_OPTIONS
    special_options_key: SPECIAL_OPTIONS_KEY
    serializer: SERIALIZER


  default_serializer: (object, prefix = null) ->
    return "" unless object?
    if !prefix and !(@get_object_type(object) is "object")
      throw new Error("Url parameters should be a javascript hash")

    s = []
    switch @get_object_type(object)
      when "array"
        for element, i in object
          s.push @default_serializer(element, prefix + "[]")
      when "object"
        for own key, prop of object
          if !prop? and prefix?
            prop = ""

          if prop?
            key = "#{prefix}[#{key}]" if prefix?
            s.push @default_serializer(prop, key)
      else
        if object?
          s.push "#{encodeURIComponent(prefix.toString())}=#{encodeURIComponent(object.toString())}"

    return "" unless s.length
    s.join("&")

  serialize: (object) ->
    custom_serializer = @configuration.serializer
    if custom_serializer? and @get_object_type(custom_serializer) is "function"
      custom_serializer(object)
    else
      @default_serializer(object)

  clean_path: (path) ->
    path = path.split("://")
    last_index = path.length - 1
    path[last_index] = path[last_index].replace(/\/+/g, "/")
    path.join "://"

  extract_options: (number_of_params, args) ->
    last_el = args[args.length - 1]
    if (args.length > number_of_params and last_el == undefined) or (last_el? and "object" is @get_object_type(last_el) and !@looks_like_serialized_model(last_el))
      options = args.pop() || {}
      delete options[@configuration.special_options_key]
      options
    else
      {}

  looks_like_serialized_model: (object) ->
    !object[@configuration.special_options_key] and ("id" of object or "to_param" of object)


  path_identifier: (object) ->
    return "0"  if object is 0
    # null, undefined, false or ''
    return "" unless object
    property = object
    if @get_object_type(object) is "object"
      if "to_param" of object
        throw new ParameterMissing("Route parameter missing: to_param") unless object.to_param?
        property = object.to_param
      else if "id" of object
        throw new ParameterMissing("Route parameter missing: id") unless object.id?
        property = object.id
      else
        property = object

      property = property.call(object) if @get_object_type(property) is "function"
    property.toString()

  clone: (obj) ->
    return obj if !obj? or "object" isnt @get_object_type(obj)
    copy = obj.constructor()
    copy[key] = attr for own key, attr of obj
    copy

  merge: (xs...) ->
    tap = (o, fn) -> fn(o); o
    if xs?.length > 0
      tap {}, (m) -> m[k] = v for k, v of x for x in xs

  normalize_options: (parts, required_parts, default_options, actual_parameters) ->
    options = @extract_options(parts.length, actual_parameters)

    if actual_parameters.length > parts.length
      throw new Error("Too many parameters provided for path")

    use_all_parts = actual_parameters.length > required_parts.length
    parts_options = {}

    for own key of options
      use_all_parts = true
      if @indexOf(parts, key) >= 0
        parts_options[key] = value

    options = @merge(@configuration.default_url_options, default_options, options)
    result = {}
    url_parameters = {}
    result['url_parameters'] = url_parameters
    for own key, value of options
      if @indexOf(ReservedOptions, key) >= 0
        result[key] = value
      else
        url_parameters[key] = value

    route_parts = if use_all_parts then parts else required_parts
    i = 0
    for part in route_parts when i < actual_parameters.length
      unless parts_options.hasOwnProperty(part)
        url_parameters[part] = actual_parameters[i]
        ++i

    result

  build_route: (parts, required_parts, default_options, route, full_url, args) ->
    args = Array::slice.call(args)

    options = @normalize_options(parts, required_parts, default_options, args)
    parameters = options['url_parameters']

    # path
    result = "#{@get_prefix()}#{@visit(route, parameters)}"
    url = Utils.clean_path(result)
    # set trailing_slash
    url = url.replace(/(.*?)[\/]?$/, "$1/") if options['trailing_slash'] is true
    # set additional url params
    if (url_params = @serialize(parameters)).length
      url += "?#{url_params}"
    # set anchor
    url += if options.anchor then "##{options.anchor}" else ""
    if full_url
      url = @route_url(options) + url
    url

  #
  # This function is JavaScript impelementation of the
  # Journey::Visitors::Formatter that builds route by given parameters
  # from route binary tree.
  # Binary tree is serialized in the following way:
  # [node type, left node, right node ]
  #
  # @param  {Boolean} optional  Marks the currently visited branch as optional.
  # If set to `true`, this method will not throw when encountering
  # a missing parameter (used in recursive calls).
  #
  visit: (route, parameters, optional = false) ->
    [type, left, right] = route
    switch type
      when NodeTypes.GROUP
        @visit left, parameters, true
      when NodeTypes.STAR
        @visit_globbing left, parameters, true
      when NodeTypes.LITERAL, NodeTypes.SLASH, NodeTypes.DOT
        left
      when NodeTypes.CAT
        left_part = @visit(left, parameters, optional)
        right_part = @visit(right, parameters, optional)
        if optional and ((@is_optional_node(left[0]) and not left_part) or
                                     ((@is_optional_node(right[0])) and not right_part))
          return ""
        "#{left_part}#{right_part}"
      when NodeTypes.SYMBOL
        value = parameters[left]
        delete parameters[left]
        if value?
          return @encode_segment(@path_identifier(value))
        if optional
          "" # missing parameter
        else
          throw new ParameterMissing("Route parameter missing: #{left}")
      #
      # I don't know what is this node type
      # Please send your PR if you do
      #
      # when NodeTypes.OR:
      else
        throw new Error("Unknown Rails node type")

  encode_segment: (segment) -> segment.replace(UriEncoderSegmentRegex, (str) -> encodeURIComponent(str))

  is_optional_node: (node) -> @indexOf([NodeTypes.STAR, NodeTypes.SYMBOL, NodeTypes.CAT], node) >= 0

  #
  # This method build spec for route
  #
  build_path_spec: (route, wildcard=false) ->
    [type, left, right] = route
    switch type
      when NodeTypes.GROUP
        "(#{@build_path_spec(left)})"
      when NodeTypes.CAT
        "#{@build_path_spec(left)}#{@build_path_spec(right)}"
      when NodeTypes.STAR
        @build_path_spec(left, true)
      when NodeTypes.SYMBOL
        if wildcard is true
          "#{if left[0] is '*' then '' else '*'}#{left}"
        else
          ":#{left}"
      when NodeTypes.SLASH, NodeTypes.DOT, NodeTypes.LITERAL
        left
      # Not sure about this one
      # when NodeTypes.OR
      else throw new Error("Unknown Rails node type")

  #
  # This method convert value for globbing in right value for rails route
  #
  visit_globbing: (route, parameters, optional) ->
    [type, left, right] = route
    value = parameters[left]
    delete parameters[left]
    return @visit(route, parameters, optional) unless value?
    value = switch @get_object_type(value)
      when "array"
        value.join("/")
      else
        value

    if DeprecatedGlobbingBehavior
      @path_identifier(value)
    else
      encodeURI(@path_identifier(value))

  #
  # This method check and return prefix from options
  #
  get_prefix: ->
    prefix = @configuration.prefix
    prefix = (if prefix.match("/$") then prefix else "#{prefix}/") if prefix isnt ""
    prefix

  #
  # route function: create route path function and add spec to it
  #
  route: (parts_table, default_options, route_spec, full_url) ->
    required_parts = []
    parts = []
    for [part, required] in parts_table
      parts.push(part)
      required_parts.push(part) if required

    path_fn = -> Utils.build_route(
      parts, required_parts, default_options, route_spec, full_url, arguments
    )
    path_fn.required_params = required_parts
    path_fn.toString = -> Utils.build_path_spec(route_spec)
    path_fn


  route_url: (route_defaults) ->
    return route_defaults if typeof route_defaults == 'string'

    hostname = route_defaults.host || Utils.current_host()

    return '' unless hostname

    subdomain = if route_defaults.subdomain then route_defaults.subdomain + '.' else ''
    protocol = route_defaults.protocol || Utils.current_protocol()
    port = route_defaults.port || (Utils.current_port() unless route_defaults.host)
    port = if port then ":#{port}" else ''

    protocol + "://" + subdomain + hostname + port

  has_location: -> window?.location?

  current_host: ->
    if @has_location() then window.location.hostname else null

  current_protocol: () ->
    if @has_location() && window.location.protocol != ''
      # location.protocol includes the colon character
      window.location.protocol.replace(/:$/, '')
    else
      'http'

  current_port: () ->
    if @has_location() && window.location.port != ''
      window.location.port
    else
      ''

  #
  # This is helper method to define object type.
  # The typeof operator is probably the biggest design flaw of JavaScript, simply because it's basically completely broken.
  #
  # Value               Class      Type
  # -------------------------------------
  # "foo"               String     string
  # new String("foo")   String     object
  # 1.2                 Number     number
  # new Number(1.2)     Number     object
  # true                Boolean    boolean
  # new Boolean(true)   Boolean    object
  # new Date()          Date       object
  # new Error()         Error      object
  # [1,2,3]             Array      object
  # new Array(1, 2, 3)  Array      object
  # new Function("")    Function   function
  # /abc/g              RegExp     object
  # new RegExp("meow")  RegExp     object
  # {}                  Object     object
  # new Object()        Object     object
  #
  # What is why I use Object.prototype.toString() to know better type of variable. Or use jQuery.type, if it available.
  # _classToTypeCache used for perfomance cache of types map (underscore at the beginning mean private method - of course it doesn't realy private).
  #
  _classToTypeCache: null
  _classToType: ->
    return @_classToTypeCache if @_classToTypeCache?
    @_classToTypeCache = {}
    for name in "Boolean Number String Function Array Date RegExp Object Error".split(" ")
      @_classToTypeCache["[object #{name}]"] = name.toLowerCase()
    @_classToTypeCache
  get_object_type: (obj) ->
    return root.jQuery.type(obj) if root.jQuery and root.jQuery.type?
    return "#{obj}" unless obj?
    (if typeof obj is "object" or typeof obj is "function" then @_classToType()[Object::toString.call(obj)] or "object" else typeof obj)

  # indexOf helper
  indexOf: (array, element) -> if Array::indexOf then array.indexOf(element) else @indexOfImplementation(array, element)
  indexOfImplementation: (array, element) ->
    result = -1
    (result = i for el, i in array when el is element)
    result

  # assign helper
  assign: (target, sources...) -> if typeof Object.assign == 'function' then Object.assign(target, sources...) else @assignImplementation(target, sources...)
  assignImplementation: (target, sources...) ->
    if target == null or target == undefined
      throw new TypeError('Cannot convert undefined or null to object')
    to = Object(target)
    index = 1
    while index < arguments.length
      nextSource = arguments[index]
      if nextSource != null and nextSource != undefined
        for nextKey of nextSource
          # Avoid bugs when hasOwnProperty is shadowed
          if Object::hasOwnProperty.call(nextSource, nextKey)
            to[nextKey] = nextSource[nextKey]
      index++
    to

  namespace: (root, namespace, routes) ->
    parts = if namespace then namespace.split(".") else []
    return routes if parts.length == 0
    for part, index in parts
      if index < parts.length - 1
        root = (root[part] or= {})
      else
        return root[part] = routes

  configure: (new_config) ->
    @configuration = @merge(@configuration, new_config)

  config: ->
    @clone(@configuration)

  make: ->
    routes = ROUTES
    routes.configure = (config) -> Utils.configure(config)
    routes.config = -> Utils.config()
    routes.default_serializer = (object, prefix) ->
      Utils.default_serializer(object, prefix)
    # Browser globals
    Utils.namespace(root, NAMESPACE, routes)
    @assign({default: routes}, routes)

result = Utils.make()
# Set up Routes appropriately for the environment.
if typeof define is "function" and define.amd
  # AMD
  define [], -> result
return result

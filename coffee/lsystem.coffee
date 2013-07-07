class Param
  @urlPrefix: "p"
  constructor:(@name,@value,@growth) ->
  toUrlComponent: -> "#{@constructor.urlPrefix}.#{@name}=#{@value},#{@growth}"
  @fromUrlComponent: (x) ->
    if (x||"").indexOf("#{@urlPrefix}.") != 0 then return undefined
    parts = x.split('=')
    name = parts[0].substring(2)
    vars = parts[1].split(',').map((v) -> parseFloat(v))
    return new @(name,vars[0],vars[1])
  @fromJson: (json) -> new @(json.name, json.value, json.growth)
  toJson: -> {
    name: @name
    value: @value
    growth: @growth
  }
  clone: -> Param.fromJson(@.toJson())

class Sensitivity extends Param
  @urlPrefix: "s"

# =========================================
class Defaults
  @offsets: (input) -> Util.merge({
    x: 0
    y: 0
    rot: 0
  }, input)
  @params: (input) -> Util.map(Util.merge(Defaults._params(), input), (p,k) -> _.extend(p, {name:k}))
  @_params: ->
    size: {value:1, growth: 0.01}
    angle: {value:1, growth: 0.05}
  @sensitivities: (input) -> Util.map(Util.merge(Util.merge(Defaults.params(), Defaults._sensitivites()), input), (p,k) -> _.extend(p, {name:k}))
  @_sensitivites: ->
    size: {value: 2.3, growth:2.47}
    angle: {value: 2.4, growth:6}

# =========================================
class LSystem
  constructor: (params, offsets, sensitivities, @rules, @iterations, @name) ->
    @params = Util.map(Defaults.params(params), (c) -> Param.fromJson(c))
    @offsets = Defaults.offsets(offsets)
    @sensitivities = Util.map(Defaults.sensitivities(sensitivities), (s) -> Sensitivity.fromJson(s))

  # this is not the most efficient of methods...
  clone: -> return LSystem.fromUrl(@toUrl())

  toUrl: ->
    base = "#?i=#{@iterations}&r=#{encodeURIComponent(@rules)}"
    mkQueryString = (params) -> _.reduce(params, ((acc,v) -> "#{acc}&#{v.toUrlComponent()}"), "")
    params = mkQueryString(@params)
    sensitivities = mkQueryString(@sensitivities)
    offsets = "&offsets=#{@offsets.x},#{@offsets.y},#{@offsets.rot}"
    return base+params+sensitivities+offsets

  @fromUrl: (url = location.hash) ->
    return null if url == ""

    params = {}
    sensitivities = {}
    config = {}
    _.each(url.substring(2).split("&").map( (x) -> x.split("=")), ([k,v]) ->
        param = Param.fromUrlComponent("#{k}=#{v}")
        sensitivity = Sensitivity.fromUrlComponent("#{k}=#{v}")
        if param then params[param.name] = param.toJson()
        else if sensitivity then sensitivities[sensitivity.name] = sensitivity.toJson()
        else config[k] = v
        config[k] = parseInt(v) if k == 'i'
    )
    offsets = undefined
    if (config.offsets)
      o = config.offsets.split(',')
      offsets =
        x: parseFloat(o[0])
        y: parseFloat(o[1])
        rot: parseFloat(o[2])

    return new LSystem(params, offsets, sensitivities, decodeURIComponent(config.r), config.i, "unnamed")

  isIsomorphicTo: (system) -> if (!system) then false else @rules == system.rules and @iterations == system.iterations

# =========================================
class CompiledSystem
  constructor: (@system, @elements) ->

# =========================================
class SystemCompiler
  _halt: false
  cache:
    system: null
    elements: null

  whenCompiled: (system, callback) ->
    if (system.isIsomorphicTo(@cache.system))
      callback(@cache.elements)
    else @compile(system, callback)

  compile: (system, callback) ->
    @_halt = false
    @cache.system = system.clone()

    textRules = system.rules.split("\n").map (r) -> (r.replace(/\ /g, '')).split(':')

    ruleMap = Util.toObj(textRules)
    seed = _.keys(ruleMap)[0] #choose first rule as system initialiser

    removeNonInstructions = (expr) -> expr.split('').filter((e) -> true if (Renderer.prototype.definitions[e]))

    expandChunk = (elems, acc, start, end) ->
      i = start
      while (i < end)
        symbol = elems[i++]
        acc += ruleMap[symbol] || symbol
      acc

    expandLevel = (expr) =>
      acc = ''
      es = expr.split('')
      at = 0
      while (at < es.length)
        chunkSize = Math.min(1000, es.length - at)
        acc = expandChunk(es,acc,at,at+chunkSize)
        at += chunkSize
      acc


    expandN = (i,expr) =>
      console.log(i);
      if (@_halt or i==0)
        @cache.elements = removeNonInstructions(expr)
        callback(@cache.elements)
      else
        setTimeout( ( -> expandN(i-1,expandLevel(expr))), 0)

    expandN(system.iterations, seed)

  halt: -> @_halt = true;

# =========================================

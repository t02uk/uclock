__DEBUG__ = false



class Util
  @pad: (str, padWith, len) ->
    refrain = (str, len) -> Array(len + 1).join(str)
    (refrain(padWith, len) + str).slice(-len)
  @zeroPad = (str, len) -> Util.pad(str, "0", len)

class God
  @setup: ->
    @deviceWidth = 640.0
    @deviceHeight = 480.0
    @scene = new THREE.Scene()
    @camera = new THREE.PerspectiveCamera(90, @deviceWidth / @deviceHeight, Math.pow(0.1, 8), Math.pow(10, 3))
    @renderer = new THREE.WebGLRenderer(antialias: true)
    @renderer.setSize(@deviceWidth, @deviceHeight)
    @renderer.setClearColor(0xffffff, 0)
    @cm = new CameraController(@camera)
    @letterSecs = for i in [0..59]
      new LetterSec(@scene, i)
    @letterMin = new LetterMin(@scene)

    @effecter = new Effecter(@renderer.domElement, document.getElementById('c'))

  @start: ->
    hour  = min  = s  = ms  = -1
    hour_ = min_ = s_ = ms_ = -1

    render = =>
      date = new Date()
      [hour, min, s, ms] = [date.getHours(), date.getMinutes(), date.getSeconds(), date.getMilliseconds()]

      if s isnt s_
        @cm.lookLetter(@letterSecs[s])

      @cm.update()

      if min isnt min_ and s is 0
        for letterSec in @letterSecs
          letterSec.z = 100

      for letterSec in @letterSecs
        letterSec.update(ms)

      @letterMin.update(Util.zeroPad(hour, 2) + ":" + Util.zeroPad(min, 2))

      requestAnimationFrame(render)
      @renderer.render(@scene, @camera)

      @effecter.update(@cm.movingLength)
      [hour_, min_, s_, ms_] = [hour, min, s, ms]
    render()


class CameraController
  constructor: (@camera) ->
    @lookAt = new THREE.Vector3(0, 0, 0)
  lookLetter: (lookedLetter) ->
    @lookedLetter = lookedLetter
  update: ->
    lp = @lookedLetter.position()
    _pos = @camera.position.clone()
    @camera.position.x = (@camera.position.x * 19 + lp.x * 1.5) / 20
    @camera.position.y = (@camera.position.y * 19 + lp.y * 1.5) / 20
    @camera.position.z = (@camera.position.z * 19 + lp.z * 1.5) / 20
    @lookAt.x = (@lookAt.x * 4 + lp.x) / 5
    @lookAt.y = (@lookAt.y * 4 + lp.y) / 5
    @lookAt.z = (@lookAt.z * 4 + lp.z) / 5
    @camera.lookAt(@lookAt)

    @movingLength = _pos.distanceTo(@camera.position)

class LetterAggregater
  @letters: []
  @append: (LetterSec) ->
    LetterAggregater.letters.push(LetterSec)


class LetterBase
  @textureMemo: {}
  constructor: (@scene, @number, @size, @digits, @color) ->
    @material = @retrieveMaterial(@number, @digits, @color)
    @geometry = new THREE.PlaneGeometry(@size, @size)
    @mesh = new THREE.Mesh(@geometry, @material)
    @scene.add(@mesh)

  position: ->
    @mesh.position
  rotation: ->
    @mesh.rotation
  retrieveMaterial: (number, digits, color) ->
    @material = new THREE.MeshBasicMaterial
      map: @makeTexture(number, digits)
      transparent: true
      color: color
      depthTest: false
      side: THREE.DoubleSide

  makeTexture: (number, digits) ->
    key = "#{number}"
    unless LetterBase.textureMemo[key]
      @canvas = document.createElement('canvas')
      width = @canvas.width = 64 * digits
      height = @canvas.height = 128
      ctx = @canvas.getContext('2d')
      ctx.textAlign = 'center'
      ctx.textBaseLine = 'top'
      ctx.font = "#{height * 3 / 4}px sans-serif"
      ctx.fillStyle = "rgb(255, 255, 255)"
      ctx.fillText(number, width / 2, height * 3 / 4)

      @texture = THREE.ImageUtils.loadTexture(@canvas.toDataURL())
      LetterBase.textureMemo[key] = @texture
      document.body.appendChild(@canvas) if __DEBUG__
    LetterBase.textureMemo[key]

class LetterMin extends LetterBase
  constructor: (scene, number) ->
    super(scene, number, 5, 5, 0x999999)
    @c = 0
  update: (number) ->
    if @number isnt number
      @material.map = @makeTexture(number, 5)
    @mesh.rotation.x += Math.sin(@c * 0.01 + 0.0) * 0.02
    @mesh.rotation.y += Math.sin(@c * 0.02 + 0.5) * 0.02
    @mesh.rotation.z += Math.sin(@c * 0.03 + 1.0) * 0.02
    @material.needsUpdate = true

    @number = number
    @c++

class LetterSec extends LetterBase
  constructor: (scene, number) ->
    super(scene, number, 1, 2, ~~(Math.random() * 0x666666) + 0x666666)

    last = if LetterAggregater.letters.length > 0
      LetterAggregater.letters[LetterAggregater.letters.length - 1].mesh.rotation
    else
      new THREE.Euler()

    loop
      if Math.random() > 0.2
        @mesh.rotation.x = last.x + Math.random() * 1.5 - 0.75
        @mesh.rotation.y = last.y + Math.random() * 1.5 - 0.75
        @mesh.rotation.z = last.z + Math.random() * 1.5 - 0.75
      else
        @mesh.rotation.x = Math.random() * Math.PI * 2 - Math.PI
        @mesh.rotation.y = Math.random() * Math.PI * 2 - Math.PI
        @mesh.rotation.z = Math.random() * Math.PI * 2 - Math.PI

      @mesh.position.set(0, 0, 5)
      @mesh.position.applyEuler(@mesh.rotation)
      needForRetry = false
      for that in LetterAggregater.letters
        if that.position().distanceToSquared(@position()) < 0.8
          needForRetry = true
          break
      break unless needForRetry

    LetterAggregater.append(@)
    @z = 100
    @tz = 6
  update: (ms) ->
    @z = (@tz + @z * 9) / 10
    @mesh.position.set(0, 0, @z)
    @mesh.position.applyEuler(@mesh.rotation)

class Effecter
  constructor: (@fromCanvas, @destCanvas) ->
    @destCtx = @destCanvas.getContext('2d')
  update: (power) ->
    f = power * 3 + 0.25
    f = 0.7 if f > 0.7
    for i in [0...40]
      i *= 0.025
      dy = i * 480 + (Math.random() * 40 - 20) * f * f
      dx = (Math.random() * 40 - 20) * f * f
      sy = i * 480
      sh = dh = i * 480

      @destCtx.globalAlpha = 0.05 * f + 0.1
      @destCtx.globalCompositeOperation = 'source-over'
      @destCtx.fillStyle = 'rgb(0, 0, 0)'

      @destCtx.drawImage(@fromCanvas, 
        0, sy,
        640, sh,
        dx, dy,
        640, dh
      )

window.God = God

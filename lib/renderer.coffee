path = require 'path'
_ = require 'underscore-plus'
cheerio = require 'cheerio'
fs = require 'fs-plus'
{$} = require 'atom-space-pen-views'
roaster = null # Defer until used
{scopeForFenceName} = require './extension-helper'
wsd = require 'websequencediagrams'

{resourcePath} = atom.getLoadSettings()
packagePath = path.dirname(__dirname)

exports.toDOMFragment = (text = '', filePath, callback) ->
  render text, filePath, (error, html) ->
    return callback(error) if error?

    template = document.createElement('template')
    template.innerHTML = html
    domFragment = template.content.cloneNode(true)

    callback(null, domFragment)

exports.toHTML = (text = '', filePath, callback) ->
  render text, filePath, (error, html) ->
    return callback(error) if error?
    callback(null, html)

render = (text, filePath, callback) ->
  if text.length > 0
    wsd.diagram text, 'magazine', 'png', (err, buf, typ) ->
      html = ""
      if err
        console.error(err);
      else
        console.log("Received MIME type:", typ);
        img = buf.toString('base64');
        html = "<html><body><img src='data:image/png;base64,#{img}'></img></body></html>"

      callback(null, html)


sanitize = (html) ->
  o = cheerio.load(html)
  o('script').remove()
  attributesToRemove = [
    'onabort'
    'onblur'
    'onchange'
    'onclick'
    'ondbclick'
    'onerror'
    'onfocus'
    'onkeydown'
    'onkeypress'
    'onkeyup'
    'onload'
    'onmousedown'
    'onmousemove'
    'onmouseover'
    'onmouseout'
    'onmouseup'
    'onreset'
    'onresize'
    'onscroll'
    'onselect'
    'onsubmit'
    'onunload'
  ]
  o('*').removeAttr(attribute) for attribute in attributesToRemove
  o.html()

# resolveImagePaths = (html, filePath) ->
#   o = cheerio.load(html)
#   for imgElement in o('img')
#     img = o(imgElement)
#     if src = img.attr('src')
#       continue if src.match(/^(https?|atom):\/\//)
#       continue if src.startsWith(process.resourcesPath)
#       continue if src.startsWith(resourcePath)
#       continue if src.startsWith(packagePath)
#
#       if src[0] is '/'
#         unless fs.isFileSync(src)
#           img.attr('src', atom.project.getDirectories()[0]?.resolve(src.substring(1)))
#       else
#         img.attr('src', path.resolve(path.dirname(filePath), src))
#
#   o.html()

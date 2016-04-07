uuid = require "node-uuid"

module.exports =

	fixAllRefs: (resources, subs) ->
		fixed = []
		for resource, i in resources
			resource = resource.toJS() if resource.toJS
			@fixRefs(resource, subs)
			fixed.push resource
		return fixed

	fixRefs: (resource, subs) ->
		count = 0
		_notDate = (value) ->
			value not instanceof Date

		_walkNode = (node) ->
			if node instanceof Array
				_walkNode v for v in node

			else if typeof node is "object" and _notDate(node)
				for k, v of node
					if k isnt "reference"
						_walkNode v
					else if v
						for sub in subs when v and sub.from and 
							v.toUpperCase() is sub.from.toUpperCase()
								node[k] = sub.to if sub.to
								count += 1

		_walkNode(resource)
		return count

	countRefs: (resources, ref) ->
		count = 0
		for resource in resources
			hasRefs = @fixRefs resource, [{from: ref}]
			if hasRefs isnt 0 then count += 1
		return count

	buildFredId: (nextId) ->
		 "FRED-#{nextId}"

	findNextId: (entries) ->
		maxId = 1
		for entry in entries
			if id = entry.resource?.id || entry.id
				if matches = id.match /^fred\-(\d+)/i
					maxId = Math.max maxId, parseInt(matches[1])+1
		return maxId

	parseBundle: (bundle, clearInternalIds) ->
		idSubs = []
		entryPos = @findNextId(bundle.entry)
		for entry in bundle.entry
			if (entry.fullUrl and /^urn:uuid:/.test entry.fullUrl) or
				!entry.resource.id or clearInternalIds
					resourceType = entry.resource.resourceType
					fromId = entry.resource.id || entry.fullUrl
					entry.resource.id = toId = @buildFredId(entryPos)
					idSubs.push {from: fromId, to: "#{resourceType}/#{toId}"}
					entryPos++


		resources = []
		for entry in bundle.entry
			@fixRefs(entry.resource, idSubs)
			resources.push entry.resource
		return resources

	generateBundle: (resources=[], splicePos=null, spliceData) ->
		if splicePos isnt null
			resources = resources.splice(splicePos, 1, spliceData)

		idSubs = []
		entries = []
		for resource in resources
			resource = resource.toJS() if resource.toJS

			if resource.id and !/^[Ff][Rr][Ee][Dd]\-\d+/.test(resource.id)
				fullUrl = "#{resource.resourceType}/#{resource.id}"
				request = {method: "PUT", url: fullUrl}
			else
				fullUrl = "urn:uuid:#{uuid.v4()}"
				request = {method: "POST", url: resource.resourceType}

				if resource.id
					fromId = "#{resource.resourceType}/#{resource.id}"
					toId = fullUrl
					idSubs.push {from: fromId, to: toId}
					delete resource.id

			entries.push
				fullUrl: fullUrl
				request: request
				resource: resource
		
		for entry in entries
			@fixRefs(entry.resource, idSubs) 
		
		return bundle = 
			resourceType: "Bundle"
			type: "transaction"
			meta:
				lastUpdated: (new Date()).toISOString()
				fhir_comments: ["Generated by FRED"]
			entry: entries





















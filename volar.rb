require 'rest-client'
require 'base64'
require 'digest/sha2'
require 'json'
require 'aws-sdk'


# SDK for interfacing with the Volar cms.  Allows pulling of lists as well
# as manipulation of records.  Requires an api user to be set up.  All
# requests (with the exception of the Volar.sites call) requires the 'site'
# parameter, and 'site' much match the slug value of a site that the given
# api user has access to.  Programmers can use the Volar.sites call to get
# this information.
# Depends on the Rest-Client and JSON gems:
# * http://rubygems.org/gems/rest-client
# * http://rubygems.org/gems/json
class Volar
	# @!attribute [String] Access this attribute to see the last error that occurred
	attr_reader :error
	# @!attribute [String] Storage of api key set by constructor
	attr_accessor :api_key
	# @!attribute [String] Storage of secret key set by constructor
	attr_accessor :secret
	# @!attribute [String] Storage of base url/domain set by constructor
	attr_accessor :base_url
	# @!attribute [Boolean] Set to true if you wish requests to occur over https rather than http
	attr_accessor :secure

	# @param [String] api_key : api key assigned to your api user
	# @param [String] secret : secret key assigned to your api user
	# @param [String] base_url : the domain that your api user is on.  Defaults to 'vcloud.volarvideo.com'
	def initialize(api_key, secret, base_url = 'vcloud.volarvideo.com')
		@api_key = api_key
		@secret = secret
		@base_url = base_url 
		@secure = false
		@error = nil
	end

	# gets list of sites
	# 
	# @param [Hash] params
	#   * optional
	#     * 'list' : type of array.  Allowed values are 'all', 'archived', 'scheduled' or 'upcoming', 'upcoming_or_streaming', 'streaming' or 'live'
	#     * 'page': current page of listings.  pages begin at '1'
	#     * 'per_page' : number of broadcasts to display per page
	#     * 'section_id' : id of section you wish to limit list to
	#     * 'playlist_id' : id of playlist you wish to limit list to
	#     * 'id' : id of site - useful if you only want to get details of a single site
	#     * 'slug' : slug of site.  useful for searches, as this accepts incomplete titles and returns all matches.
	#     * 'title' : title of site.  useful for searches, as this accepts incomplete titles and returns all matches.
	#     * 'sort_by' : data field to use to sort.  allowed fields are date, status, id, title, description
	#     * 'sort_dir' : direction of sort.  allowed values are 'asc' (ascending) and 'desc' (descending)
	# @return false on failure, hash on success.  if failed, Volar.error can be used to get last error string
	def sites(params = {})
		results = request(route = 'api/client/info', method = 'GET', parameters = params)
		return results
	end

	# gets list of broadcasts
	# @param [Hash] params
	#   * _required_
	#     * 'site' OR 'sites'	slug of site to filter to. if passing 'sites', users can include a comma-delimited list of sites.  results will reflect all broadcasts in the listed sites.
	#   * _optional_
	#     * 'list' : type of array.  allowed values are 'all', 'archived', 'scheduled' or 'upcoming', 'upcoming_or_streaming', 'streaming' or 'live'
	#     * 'page' : current page of listings.  pages begin at '1'
	#     * 'per_page' : number of broadcasts to display per page
	#     * 'section_id' : id of section you wish to limit list to
	#     * 'playlist_id' : id of playlist you wish to limit list to
	#     * 'id' : id of broadcast - useful if you only want to get details of a single broadcast
	#     * 'title' : title of broadcast.  useful for searches, as this accepts incomplete titles and returns all matches.
	#     * 'template_data' : hash.  search broadcast template data.  should be in the form:
	#        ```
	#        {
	#          'field title' : 'field value',
	#          'field title' : 'field value',
	#          ....
	#        }
	#        ```
	#     * 'autoplay' : true or false.  defaults to false.  used in embed code to prevent player from immediately playing
	#     * 'embed_width' : width (in pixels) that embed should be.  defaults to 640
	#     * 'sort_by' : data field to use to sort.  allowed fields are date, status, id, title, description
	#     * 'sort_dir' : direction of sort.  allowed values are 'asc' (ascending) and 'desc' (descending)
	# @return false on failure, hash on success.  if failed, Volar.error can be used to get last error string
	def broadcasts(params = {})
		if params.has_key?('site') == false and params.has_key?('sites') == false
			@error = '"site" or "sites" parameter is required.'
			return false
		end  
		result = request(route = 'api/client/broadcast', method = '', parameters = params, post_body = nil)
		return result
	end 

	# create a new broadcast
	# @param [Hash] params
	#   * _required_
	#     * 'title' : title of the new broadcast
	#     * 'contact_name' : contact name of person we should contact if we detect problems with this broadcast
	#     * 'contact_phone' : phone we should use to contact contact_name person
	#     * 'contact_sms' : sms number we should use to send text messages to contact_name person
	#     * 'contact_email' : email address we should use to send emails to contact_name person
	#       * note that contact_phone can be omitted if contact_sms is supplied, and vice-versa
	#   * _optional_
	#     * 'description' : HTML formatted description of the broadcast.
	#     * 'status' : currently only supports 'scheduled' & 'upcoming'
	#     * 'timezone' : timezone of given date.  only timezones listed on http://php.net/manual/en/timezones.php are supported.  defaults to UTC
	#     * 'date' : date (string) of broadcast event.  will be converted to UTC if the given timezone is given.  note that if the system cannot read the date, or if it isn't supplied, it will default it to the current date & time.
	#     * 'section_id' : id of the section that this broadcast should be assigned.  the Volar.sections() call can give you a list of available sections.  Defaults to a 'General' section
	# @return [hash]
	#  ```
	#  {
	#    'success' : True or False depending on success
	#    ...
	#    if 'success' == True:
	#      'broadcast' : hash containing broadcast information, including id of new broadcast
	#    else:
	#      'errors' : list of errors to give reason(s) for failure
	#  }
	#  ```
	def broadcast_create(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		params.delete('site')
		params = JSON.generate(params)
		results = request(route = 'api/client/broadcast/create', method = 'POST', parameters = {'site' => site}, post_body = params)
		return results
	end 


	# update existing broadcast
	# @param [Hash] params
	#   * _required_
	#     * 'id' : id of broadcast you wish to update
	#   * _optional_
	#     * 'title' : title of the new broadcast.  if supplied, CANNOT be blank
	#     * 'description' : HTML formatted description of the broadcast.
	#     * 'status' : currently only supports 'scheduled' & 'upcoming'
	#     * 'timezone' : timezone of given date.  only timezones listed on http://php.net/manual/en/timezones.php are supported.  defaults to UTC
	#     * 'date' : date (string) of broadcast event.  will be converted to UTC if the given timezone is given.  note that if the system cannot read the date, or if it isn't supplied, it will default it to the current date & time.
	#     * 'section_id' : id of the section that this broadcast should be assigned.  the Volar.sections() call can give you a list of available sections.  Defaults to a 'General' section
	#     * 'contact_name' : contact name of person we should contact if we detect problems with this broadcast
	#     * 'contact_phone' : phone we should use to contact contact_name person
	#     * 'contact_sms' : sms number we should use to send text messages to contact_name person
	#     * 'contact_email' : email address we should use to send emails to contact_name person
	#       * note that contact_phone can be omitted if contact_sms is supplied, and vice-versa
	# @return [Hash]
	#  ```
	# 	{
	# 		'success' : True or False depending on success
	# 		if 'success' == True:
	# 			'broadcast' : hash containing broadcast information,
	# 				including id of new broadcast
	# 		else:
	# 			'errors' : list of errors to give reason(s) for failure
	# 	}
	#  ```
	def broadcast_update(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		params.delete('site')
		params = JSON.generate(params)
		results = request(route = 'api/client/broadcast/update', method = 'POST', parameters = {'site' => site}, post_body = params)
		return results
	end

	# delete a broadcast
	# @param [Hash] params
	#   * _required_
	#     * 'site' : slug of site that broadcast is attached to
	#     * 'id' : id of broadcast you wish to delete
	# @return [Hash] { 'success' : True }
	def broadcast_delete(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		params.delete('site')
		params = JSON.generate(params)
		results = request(route = 'api/client/broadcast/delete', method = 'POST', parameters = {'site' => site}, post_body = params)
		return results
	end
	
	# assign a broadcast to a playlist
	# @param [Hash] params
	#   * 'id' : id of broadcast
	#   * 'playlist_id' : id of playlist
	# @return [Hash] { 'success' : True }
	def broadcast_assign_playlist(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		results = request(route = 'api/client/broadcast/assignplaylist', method = 'GET', parameters = params)
		return results
	end

	# remove a broadcast from a playlist
	# @param [Hash] params
	#   * 'id' : id of broadcast
	#   * 'playlist_id' : id of playlist
	# @return [Hash] { 'success' : True }
	def broadcast_remove_playlist(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		results = request(route = 'api/client/broadcast/removeplaylist', method = 'GET', parameters = params)
		return results
	end	

	# uploads an image file as the poster for a broadcast.
	# @param [Hash] params
	#   * 'id' : id of broadcast
	#   * 'site' : slug of site that broadcast is attached to
	# @param [String] file_path (should include file name)
	#   * if supplied, this file is uploaded to the server and attached to the broadcast as an image 
	# @return [Hash]
	#   ```
	#   {
	#     'success' : True or False depending on success
	#     if 'success' == False:
	#       'errors' : list of errors to give reason(s) for failure
	#   }
	#   ```
	def broadcast_poster(params = {}, file_path = '')
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end

		if file_path == ''
			result = request(route = 'api/client/broadcast/poster', method = 'GET', parameters = params)
		else 
			fileInfo = upload_file(file_path)
			if fileInfo == false
				return false
			end
			params = params.merge(fileInfo)
			result = request(route = 'api/client/broadcast/poster', method = 'GET', parameters = params)
		end
		return result
	end 

	# archives a broadcast.
	# @param [Hash] params
	#   * 'id' : id of broadcast
	#   * 'site' : slug of site that broadcast is attached to.
	# @param [String] file_path (should include file name)
	#   * if supplied, this file is uploaded to the server and attached to the broadcast
	# @return [Hash]
	#   ```
	#   {
	#     'success' : True or False depending on success
	#     'broadcast' : hash describing broadcast that was modified.
	#     if 'success' == True:
	#       'fileinfo' : hash containing information about the uploaded file (if there was a file uploaded)
	#     else:
	#       'errors' : list of errors to give reason(s) for failure
	#   }
	#   ```
	def broadcast_archive(params = {}, file_path = '')
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end

		if file_path == ''
			result = request(route = 'api/client/broadcast/archive', method = 'GET', parameters = params)
		else 
			fileInfo = upload_file(file_path)
			if fileInfo == false
				return false
			end
			params = params.merge(fileInfo)
			result = request(route = 'api/client/broadcast/archive', method = 'GET', parameters = params)
		end
		return result
	end 

	# gets list of videoclips
	# @param [Hash] params
	#   * _required_
	#     * 'site' OR 'sites'	slug of site to filter to.  if passing 'sites', users can include a comma-delimited list of sites.  results will reflect all videoclips in the listed sites.
	#   * _optional_
	#     * 'list' : type of list.  allowed values are 'all', 'active'
	#     * 'page' : current page of listings.  pages begin at '1'
	#     * 'per_page' : number of videoclips to display per page
	#     * 'section_id' : id of section you wish to limit list to
	#     * 'playlist_id' : id of playlist you wish to limit list to
	#     * 'id' : id of videoclip - useful if you only want to get details of a single videoclip
	#     * 'title' : title of videoclip.  useful for searches, as this accepts incomplete titles and returns all matches.
	#     * 'autoplay' : true or false.  defaults to false.  used in embed code to prevent player from immediately playing
	#     * 'embed_width' : width (in pixels) that embed should be.  defaults to 640
	#     * 'sort_by' : data field to use to sort.  allowed fields are date, status, id, title, description
	#     * 'sort_dir' : direction of sort.  allowed values are 'asc' (ascending) and 'desc' (descending)
	# @return false on failure, hash on success.  if failed, Volar.error can be used to get last error string
	def videoclips(params = {})
		if params.has_key?('site') == false and params.has_key?('sites') == false
			@error = '"site" or "sites" parameter is required.'
			return false
		end  
		result = request(route = 'api/client/videoclip', method = '', parameters = params, post_body = nil)
		return result
	end 

	# create a new videoclip
	# @param [Hash] params
	#   * _required_
	#     * 'site':	slug of site to attach videoclip to
	#     * 'title' : title of the new videoclip
	#   * _optional_
	#     * 'description' : HTML formatted description of the videoclip.
	#     * 'section_id' : id of the section that this videoclip should be assigned.  the Volar.sections() call can give you a list of available sections.  Defaults to a 'General' section
	# @return [Hash]
	#   ```
	#   {
	#     'success' : True or False depending on success
	#     ...
	#     if 'success' == True:
	#       'clip' : hash containing videoclip information, including id of new videoclip
	#     else:
	#       'errors' : list of errors to give reason(s) for failure
	#   }
	#   ```
	def videoclip_create(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		params.delete('site')
		params = JSON.generate(params)
		results = request(route = 'api/client/videoclip/create', method = 'POST', parameters = {'site' => site}, post_body = params)
		return results
	end 


	# update existing videoclip
	# @param [Hash] params
	#   * _required_
	#     * 'site':	slug of site clip is associated with
	#     * 'id' : id of videoclip you wish to update
	#   * _optional_
	#     * 'title' : title of the new videoclip.  if supplied, CANNOT be blank
	#     * 'description' : HTML formatted description of the videoclip.
	#     * 'section_id' : id of the section that this videoclip should be assigned.  the Volar.sections() call can give you a list of available sections.  Defaults to a 'General' section
	# @return [Hash]
	#   ```
	#   {
	#     'success' : True or False depending on success
	#     if 'success' == True:
	#       'clip' : hash containing videoclip information, including id of new videoclip
	#     else:
	#       'errors' : list of errors to give reason(s) for failure
	#   }
	#   ```
	def videoclip_update(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		params.delete('site')
		params = JSON.generate(params)
		results = request(route = 'api/client/videoclip/update', method = 'POST', parameters = {'site' => site}, post_body = params)
		return results
	end

	# delete a videoclip
	# @param [Hash] params
	#   * _required_
	#     * 'site' : slug of site that videoclip is attached to
	#     * 'id' : id of videoclip you wish to delete
	# @return [Hash] { 'success' : True }
	def videoclip_delete(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		params.delete('site')
		params = JSON.generate(params)
		results = request(route = 'api/client/videoclip/delete', method = 'POST', parameters = {'site' => site}, post_body = params)
		return results
	end
	
	# assign a videoclip to a playlist
	# 
	# @param [Hash] params
	#   * 'id' : id of videoclip
	#   * 'playlist_id' : id of playlist
	# @return [Hash] { 'success' : True }
	def videoclip_assign_playlist(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		results = request(route = 'api/client/videoclip/assignplaylist', method = 'GET', parameters = params)
		return results
	end

	# remove a videoclip from a playlist
	# 
	# @param [Hash] params
	#   * 'id' : id of videoclip
	#   * 'playlist_id' : id of playlist
	# @return [Hash] { 'success' : True }
	def videoclip_remove_playlist(params = {})		
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		results = request(route = 'api/client/videoclip/removeplaylist', method = 'GET', parameters = params)
		return results
	end	

	# uploads an image file as the poster for a videoclip.
	# 
	# @param [Hash] params
	#   * 'id' : id of videoclip
	# @param [String] file_path (should include file name)
	#   * if supplied, this file is uploaded to the server and attached to the videoclip as an image 
	# @return:: hash
	#   ```
	#   {
	#     'success' : True or False depending on success
	#     if 'success' == False:
	#       'errors' : list of errors to give reason(s) for failure
	#   }
	#   ```
	def videoclip_poster(params = {}, file_path = '')
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end

		if file_path == ''
			result = request(route = 'api/client/videoclip/poster', method = 'GET', parameters = params)
		else 
			fileInfo = upload_file(file_path)
			if fileInfo == false
				return false
			end
			params = params.merge(fileInfo)
			result = request(route = 'api/client/videoclip/poster', method = 'GET', parameters = params)
		end
		return result
	end 

	# archives a videoclip.
	#
	# @param [Hash] params
	#   * 'id' : id of videoclip
	#   * 'site' : slug of site that videoclip is attached to.
	# @param [String] file_path (should include file name)
	#   * if supplied, this file is uploaded to the server and attached to the videoclip
	# @return [Hash]
	#   ```
	#   {
	#     'success' : True or False depending on success
	#     'clip' : hash describing videoclip that was modified.
	#     if 'success' == True:
	#       'fileinfo' : hash containing information about the uploaded file (if there was a file uploaded)
	#     else:
	#       'errors' : list of errors to give reason(s) for failure
	#   }
	#   ```
	def videoclip_archive(params = {}, file_path = '')
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end

		if file_path == ''
			result = request(route = 'api/client/videoclip/archive', method = 'GET', parameters = params)
		else 
			fileInfo = upload_file(file_path)
			if fileInfo == false
				return false
			end
			params = params.merge(fileInfo)
			result = request(route = 'api/client/videoclip/archive', method = 'GET', parameters = params)
		end
		return result
	end 

	# gets list of meta-data templates
	# 
	# @param [Hash] params
	#   * _required_
	#     * 'site' : slug of site to filter to.  note that 'sites' is not supported
	#   * _optional_
	#     * 'page' : current page of listings.  pages begin at '1'
	#     * 'per_page' : number of broadcasts to display per page
	#     * 'broadcast_id' : id of broadcast you wish to limit list to.
	#     * 'section_id' : id of section you wish to limit list to.
	#     * 'id' : id of template - useful if you only want to get details of a single template
	#     * 'title' : title of template.  useful for searches, as this accepts incomplete titles and returns all matches.
	#     * 'sort_by' : data field to use to sort.  allowed fields are id, title, description, date_modified. defaults to title
	#     * 'sort_dir' : direction of sort.  allowed values are 'asc' (ascending) and 'desc' (descending). defaults to asc
	# @return false on failure, hash on success.  if failed, Volar.error can be used to get last error string
	def templates(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = '"site" parameter is required'
			return false
		end
		result = request(route = 'api/client/template', method = '', parameters = params)
		return result
	end 

	# create a new meta-data template
	# 
	# @param [Hash] params
	#   * _required_
	#     * 'site' : slug of site to filter to.  note that 'sites' is not supported
	#     * 'title' : title of the broadcast
	#     * 'data' : list of data fields (hashes) assigned to template. should be in format:
	# 
	#         ```
	#         [
	#           {
	#             "title" : (string) "field title",
	#             "type" : (string) "type of field",
	#             "options" : {...} or [...]	//only include if type supports
	#           },
	#           ...
	#         ]
	#         ```
	# 
	#         supported types are:
	#         * 'single-line' - single line of text
	#         * 'multi-line' - multiple-lines of text, option 'rows' (not required) is number of lines html should display as. ex: "options": {'rows': 4}
	#         * 'checkbox' - togglable field.  value will be the title of the field.  no options.
	#         * 'checkbox-list' - list of togglable fields.  values should be included in 'options' list. ex: "options" : ["option 1", "option 2", ...]
	#         * 'radio' - list of selectable fields, although only 1 can be selected at at time.  values should be included in 'options' list. ex: "options" : ["option 1", "option 2", ...]
	#         * 'dropdown' - same as radio, but displayed as a dropdown. values should be included in 'options' array. ex: "options" : ["option 1", "option 2", ...]
	#         * 'country' - dropdown containing country names.  if you wish to specify default value, include "default_select".  this should not be passed as an option, but as a seperate value attached to the field, and accepts 2-character country abbreviation.
	#         * 'state' - dropdown containing united states state names.  If you wish to specify default value, include "default_select". this should not be passed as an option, but as a seperate value attached to the field, and accepts 2-character state abbreviation.
	#   * _optional_
	#     * 'description' : text used to describe the template.
	#     * 'section_id' : id of section to assign broadcast to. will default to 'General'.
	# @return [Hash]
	#  ```
	#  {
	#    'success' : True or False depending on success
	#    ...
	#    if 'success' == True:
	#      'template' : hash containing template information, including id of new template
	#    else:
	#      'errors' : list of errors to give reason(s) for failure
	#  }
	#  ```
	def template_create(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		params.delete('site')
		params = JSON.generate(params)
		results = request(route = 'api/client/template/create', method = 'POST', parameters = {'site' => site}, post_body = params)
		return results
	end 

	# update an existing meta-data template
	# 
	# @param [Hash] params
	#   * _required_
	#     * 'site' : slug of site to filter to.  note that 'sites' is not supported
	#     * 'id' : numeric id of template that you are intending to update.
	#   * _optional_
	#     * 'title' : title of the broadcast
	#     * 'data' : list of data fields assigned to template.  see template_create() for format
	#     * 'description' : text used to describe the template.
	#     * 'section_id' : id of section to assign broadcast to. will default to 'General'.
	# @return [Hash]
	#   ```
	#   {
	#     'success' : True or False depending on success
	#     ...
	#     if 'success' == True:
	#       'template' : hash containing template information, including id of new template
	#     else:
	#       'errors' : list of errors to give reason(s) for failure
	#   }
	#   ```
	# Note that if you do not have direct access to update a template (it may be domain or client level), a new template will be created and returned to you that does have the permissions set for you to modify.  keep this in mind when updating templates.
	def template_update(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		params.delete('site')
		params = JSON.generate(params)
		results = request(route = 'api/client/template/update', method = 'POST', parameters = {'site' => site}, post_body = params)
		return results
	end

	# delete a meta-data template
	# the only parameter (aside from 'site') that this function takes is 'id'
	def template_delete(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		params.delete('site')
		params = JSON.generate(params)
		results = request(route = 'api/client/template/delete', method = 'POST', parameters = {'site' => site}, post_body = params)
		return results
	end 

	# gets list of sections
	# 
	# @param [Hash] params
	#   * _required_
	#     * 'site' OR 'sites'	slug of site to filter to. if passing 'sites', users can include a comma-delimited list of sites.  results will reflect all sections in the listed sites.
	#   * _optional_
	#     * 'page' : current page of listings.  pages begin at '1'
	#     * 'per_page' : number of broadcasts to display per page
	#     * 'broadcast_id' : id of broadcast you wish to limit list to. will always return 1
	#     * 'video_id' : id of video you wish to limit list to.  will always return 1.  note this is not fully supported yet.
	#     * 'id' : id of section - useful if you only want to get details of a single section
	#     * 'title' : title of section.  useful for searches, as this accepts incomplete titles and returns all matches.
	#     * 'sort_by' : data field to use to sort.  allowed fields are id, title
	#     * 'sort_dir' : direction of sort.  allowed values are 'asc' (ascending) and 'desc' (descending)
	# @return false on failure, hash on success.  if failed, Volar.error can be used to get last error string
	def sections(params = {})
		if params.has_key?('site') == false and params.has_key?('sites') == false
			@error = '"site" or "sites" parameter is required.'
			return false
		end  
		result = request(route = 'api/client/section', method = '', parameters = params)
		return result
	end

	# gets list of playlists
	#
	# @param [Hash] params
	#   * _required_
	#     * 'site' OR 'sites'	slug of site to filter to.  if passing 'sites', users can include a comma-delimited list of sites.  results will reflect all playlists in the listed sites.
	#   * _optional_
	#     * 'page' : current page of listings.  pages begin at '1'
	#     * 'per_page' : number of broadcasts to display per page
	#     * 'broadcast_id' : id of broadcast you wish to limit list to.
	#     * 'video_id' : id of video you wish to limit list to.  note this is not fully supported yet.
	#     * 'section_id' : id of section you wish to limit list to
	#     * 'id' : id of playlist - useful if you only want to get details of a single playlist
	#     * 'title' : title of playlist.  useful for searches, as this accepts incomplete titles and returns all matches.
	#     * 'sort_by' : data field to use to sort.  allowed fields are id, title
	#     * 'sort_dir' : direction of sort.  allowed values are 'asc' (ascending) and 'desc' (descending)
	# @return:: false on failure, hash on success.  if failed, Volar.error can be used to get last error string
	def playlists(params = {})
		if params.has_key?('site') == false and params.has_key?('sites') == false
			@error = '"site" or "sites" parameter is required.'
			return false
		end  
		result = request(route = 'api/client/playlist', method = '', parameters = params)
		return result
	end

	# create a new playlist
	# 
	# @param [Hash] params
	#   * required::
	#     * 'title' : title of the new playlist
	#   * optional::
	#     * 'description' : HTML formatted description of the playlist.
	#     * 'available' : flag whether or not the playlist is available for public viewing.  accepts 'yes','available','active', & '1' (to flag availability) and 'no','unavailable', 'inactive', & '0' (to flag non-availability)
	#     * 'section_id' : id of the section that this playlist should be assigned.  the Volar.sections() call can give you a list of available sections.  Defaults to a 'General' section
	# @return [Hash]
	#   ```
	#   {
	#     'success' : True or False depending on success
	#     ...
	#     if 'success' == True:
	#       'playlist' : hash containing playlist information, including id of new playlist
	#     else:
	#       'errors' : list of errors to give reason(s) for failure
	#   }
	#   ```
	def playlist_create(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		params.delete('site')
		params = JSON.generate(params)
		results = request(route = 'api/client/playlist/create', method = 'POST', parameters = {'site' => site}, post_body = params)
		return results
	end 
	
	# update existing playlist
	# 
	# @param [Hash] params
	#   * _required_
	#     * 'id' : id of playlist you wish to update
	#   * _optional_
	#     * 'title' : title of the new playlist.  if supplied, CANNOT be blank
	#     * 'description' : HTML formatted description of the playlist.
	#     * 'available' : flag whether or not the playlist is available for public viewing.  accepts 'yes','available','active', & '1' (to flag availability) and 'no','unavailable', 'inactive', & '0' (to flag non-availability)
	#     * 'section_id' : id of the section that this playlist should be assigned.  the Volar.sections() call can give you a list of available sections.  Defaults to a 'General' section
	# @return [Hash]
	#   ```
	#   {
	#     'success' : True or False depending on success
	#     if 'success' == True:
	#       'playlist' : hash containing playlist information, including id of playlist
	#     else:
	#       'errors' : list of errors to give reason(s) for failure
	#   }
	#   ```
	def playlist_update(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		params.delete('site')
		params = JSON.generate(params)
		results = request(route = 'api/client/playlist/update', method = 'POST', parameters = {'site' => site}, post_body = params)
		return results
	end 

	# delete a playlist
	# the only parameter (aside from 'site') that this function takes is 'id'
	def playlist_delete(params = {})
		site = params.fetch('site', nil)
		if site == nil
			@error = 'site is required'
			return false
		end
		params.delete('site')
		params = JSON.generate(params)
		results = request(route = 'api/client/playlist/delete', method = 'POST', parameters = {'site' => site}, post_body = params)
		return results
	end 

	private
	def upload_file(file_path)
		if !File.file?(file_path)
			@error = "#{file_path} does not appear to exist"
			return false
		end
		filePathBaseName = File.basename(file_path.gsub("\\", '/'))
		handshakeRes = request(route = 'api/client/broadcast/s3handshake', method = 'GET', parameters = { 'filename' => filePathBaseName });
		if handshakeRes == false
			if @error == ''
				@error = "Could not initiate file upload"
			end
			return false
		end
		returnVals = {
			'tmp_file_id' => handshakeRes['id'],
			'tmp_file_name' => handshakeRes['key']
		}
		dispositionFileName = filePathBaseName.gsub('"', '')
		begin
			s3 = AWS::S3.new(:access_key_id => handshakeRes['access_key'], :secret_access_key => handshakeRes['secret'], :session_token => handshakeRes['token'])
		rescue Exception => e
			@error = e.message
			return false
		end

		begin
			bucket = s3.buckets[handshakeRes['bucket']]
			obj = bucket.objects[handshakeRes['key']]
			file = File.open(file_path, 'rb')
			obj.write(file, :content_disposition => 'attachment; filename="' + dispositionFileName + '"', :acl => :public_read)
			file.close()
		rescue Exception => e
			@error = e.message
			return false
		end
		return returnVals


	end

	def request(route, method = '', parameters = {}, post_body = nil)
		if method == ''
			method = 'GET'
		end
		
		transformed_params={}
		parameters.each do |key, val|
			if val.instance_of?(Hash)
				val.each do |vkey, vval|
					val.sort
					transformed_params[key + '[' + convert_val_to_str(vkey) + '['] = val
				end
			else
				transformed_params[key] = val
			end
		end

		transformed_params['api_key'] = @api_key
		signature = build_signature(route, method, transformed_params, post_body)

		transformed_params['signature'] = signature
		url = '/' + route.chomp('/')
		
		if @secure
			url = 'https://' + String(@base_url) + url 
		else 
			url = 'http://' + String(@base_url) + url
		end 

		begin
			if method == 'GET'
				response = RestClient.get(url, {:params => transformed_params}){| response, request, result | response }
			else
				response = RestClient.post(url, post_body, {:params => transformed_params}){| response, request, result | response }
			end

			return JSON.parse(response)
		rescue Exception => exc
			puts exc.message 
			puts exc.backtrace.inspect
			return false
		end

	end

	def build_signature(route, method = '', get_params = {}, post_body = nil)
		if method == ''
			method = 'GET'
		end 

		route = route.chomp('/').reverse.chomp('/').reverse
		get_params = get_params.sort { |a, b| a[0].to_s <=> b[0].to_s }
		get_params = (get_params.map { |param| param.join('=') }.join);

		method = method.upcase
	
		signature = @secret.to_s + method + route + get_params
		
		if post_body != nil and post_body.is_a?(String)
			signature += post_body
		end 
		
		signature=signature.force_encoding('us-ascii')
		sha256 = Digest::SHA2.new(256)
		signature = sha256.digest(signature)
		
		signature = Base64::encode64(signature)[0..42]
		
		signature.chomp!('=')
		return signature
	end 

	def convert_val_to_str(val)
		if val.is_a(Boolean)
			if val==true
				return '1'
			else 
				return '0'
			end
		else
			return val.to_s
		end 
	end

end

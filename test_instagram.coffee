instagram = require './instagram'
_ = require 'underscore'
                
instagram.buildInitalSet (unsortedPhotos) ->

  timeSort = (item) ->
     return -1 * item.created_time_int

  sortedPhotos = _.sortBy unsortedPhotos, timeSort
  
  console.log sortedPhotos

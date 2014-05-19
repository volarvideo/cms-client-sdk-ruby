cms-client-sdk-ruby
==================

Ruby SDK for Volar's client sdk, Version 2 (pre-alpha)

Full Documentation can be found [here](http://volarvideo.github.io/cms-client-sdk-ruby/frames.html)

 + Important!
   + The broadcast_poster and videoclip_poster functions are currently disabled for a short period until they can be updated on the server to work correctly.  Please keep this in mind.  This will be the case for at least another week.

This is a rework of the existing [Ruby SDK](https://github.com/volarvideo/cms-client-sdk).  Primary purpose of the rework was to eliminate the step of uploading files directly to the volar servers - instead, when videos are archived or posters are uploaded, the files are uploaded to our remote storage and enqueued for transcode, relieving a lot of the work our servers have to do to bring content to viewers.

The downside is that the Ruby sdk now has a new dependancy - the Amazon AWS SDK.  However, installation is simplified by the inclusion of a Gemfile.

Open your terminal, navigate to the directory containing the sdk rb file, and type:

`bundle install`

This should install all dependencies required by the sdk.

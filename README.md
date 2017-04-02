# ScholarsCrawler
A Rails web application to crawl for scholars citation rankings and present them in web table view.

# Build
Install Ruby (1.8+) first then get all dependencies using:

    gem install bundler
    bundle install

# Run
To run the web app server and the background worker that crawls the sources on demand:

    foreman start
    
The default port is 5000 but you can override it using PORT env variable:

    PORT=4000 foreman start
    

#!/bin/bash -x

echo "## Updating openvidu-tutorials"

find -type f -name 'package-lock.json' -exec rm {} \;
find -type d -name 'node_modules' -exec rm -rf {} \;

# Updating openvidu-browser dependencies in package.json files [openvidu-insecure-angular, openvidu-insecure-react, openvidu-library-angular]
find . -type f -name 'package.json' -not \( -path '*/node_modules/*' -o -path '*/package-lock.json'  \) -exec sed -i 's/"openvidu-browser": "2.5.0"/"openvidu-browser": "2.6.0"/g' {} \;

# Updating openvidu-react dependencies in package.json files [openvidu-library-react]
find . -type f -name 'package.json' -not \( -path '*/node_modules/*' -o -path '*/package-lock.json'  \) -exec sed -i 's/"openvidu-react": "2.5.0"/"openvidu-react": "2.6.0"/g' {} \;

# Updating openvidu-angular dependencies in package.json files [openvidu-library-angular]
find . -type f -name 'package.json' -not \( -path '*/node_modules/*' -o -path '*/package-lock.json'  \) -exec sed -i 's/"openvidu-angular": "2.5.0"/"openvidu-angular": "2.6.0"/g' {} \;

# Run "npm install" in every npm project [openvidu-insecure-angular, openvidu-insecure-react, openvidu-library-angular, openvidu-library-react, openvidu-ionic, openvidu-js-node, openvidu-mvc-node, openvidu-recording-node]
for tutorial in openvidu-insecure-angular openvidu-insecure-react openvidu-library-angular openvidu-library-react openvidu-ionic openvidu-js-node openvidu-mvc-node openvidu-recording-node; do
    cd $tutorial && npm install && cd ..
done

# Update every <script src="openvidu-browser-VERSION.js"></script> import in every *.html or *.ejs file (10 files changed)
for file in *.html *.ejs; do
    find . -type f -name $file -not \( -path '*/node_modules/*' -o -path '*/package-lock.json'  \) -exec sed -i 's/<script src="openvidu-browser-2.5.0.js"><\/script>/<script src="openvidu-browser-2.6.0.js"><\/script>/g' {} \;
done

# Update every openvidu-browser-VERSION.js file (10 files changed)
wget https://github.com/OpenVidu/openvidu/releases/download/v2.6.0/openvidu-browser-2.6.0.js .
readarray array < <(find -name 'openvidu-browser-2.5.0.js' -printf '%h\n' | sort -u)
for directory in ${array[@]}; do
    rm $directory/openvidu-browser-2.5.0.js
    cp openvidu-browser-2.6.0.js $directory/openvidu-browser-2.6.0.js
done
rm openvidu-browser-2.6.0.js

# Update openvidu-webcomponent tutorial files: static web component files and import in index.html
wget https://github.com/OpenVidu/openvidu/releases/download/v2.6.0/openvidu-webcomponent-2.6.0.zip .
unzip openvidu-webcomponent-2.6.0.zip
rm openvidu-webcomponent/web/openvidu-webcomponent-2.5.0.js
rm openvidu-webcomponent/web/openvidu-webcomponent-2.5.0.css
cp openvidu-webcomponent-2.6.0.js openvidu-webcomponent/web/openvidu-webcomponent-2.6.0.js
cp openvidu-webcomponent-2.6.0.css openvidu-webcomponent/web/openvidu-webcomponent-2.6.0.css
rm openvidu-webcomponent-*
sed -i 's/<script src="openvidu-webcomponent-2.5.0.js"><\/script>/<script src="openvidu-webcomponent-2.6.0.js"><\/script>/g' openvidu-webcomponent/web/index.html
sed -i 's/<link rel="stylesheet" href="openvidu-webcomponent-2.5.0.css">/<link rel="stylesheet" href="openvidu-webcomponent-2.6.0.css">/g' openvidu-webcomponent/web/index.html

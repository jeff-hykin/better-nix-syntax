pkgs.stdenv.mkDerivation {
    buildPhase = ''
        export HOME=$PWD/.home
        export npm_config_cache=$PWD/.npm
        mkdir -p $out/js
        cd $out/js
        cp -r $src/. .

        while read package
        do
            echo "caching $package"
            npm cache add "$package"
        done <${tarballsFile}
        
        question="question? [y/n]";answer=""
        while true; do
            echo "$question"; read response
            case "$response" in
                [Yy]* ) answer='yes'; break;;
                [Nn]* ) answer='no'; break;;
                * ) echo "Please answer yes or no.";;
            esac
        done

        if [ "$answer" = 'yes' ]; then
            do_something
        else
            do_something_else
        fi

        npm ci
    '';

    installPhase = ''
        ln -s $out/js/node_modules/.bin $out/bin
    '';
}
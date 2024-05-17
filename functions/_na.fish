# package manager detection logic is based on [kKaribash/ni.fish]
# Original Source: https://github.com/Karibash/ni.fish/blob/main/functions/ni.fish

function _na
    _na_get_package_manager_name $PWD
end

function _na_find_up --argument-names path
    set files $argv[2..]
    for file in $files
        test -e "$path/$file" && echo $path/$file && return
    end

    test ! -z "$path" || return
    _na_find_up (string replace --regex -- '/[^/]*$' "" $path) $files
end

function _na_find_lock_file --argument-names path
    _na_find_up $path deno.lock package-lock.json npm-shrinkwrap.json yarn.lock pnpm-lock.yaml bun.lockb
end

function _na_find_package_json --argument-names path
    _na_find_up $path package.json
end

function _na_find_deno_json --argument-names path
    _na_find_up $path deno.json deno.jsonc
end

function _na_select_package_manager_with_fzf --argument-names path
    set -l package_manager_names npm pnpm bun yarn deno
    set -l fuzzy_finder
    [ -n "$NA_FUZZY_FINDER" ]; and set fuzzy_finder $NA_FUZZY_FINDER; or set fuzzy_finder fzf

    echo ( for i in $package_manager_names; echo $i; end  | $fuzzy_finder)
end

function _na_get_package_manager_name --argument-names path
    set lock_file_path (_na_find_lock_file $path)
    set deno_json_path (_na_find_deno_json $path)
    set package_json_path (test -n "$lock_file_path" && _na_find_package_json $lock_file_path || _na_find_package_json $path)

    if test -n "$deno_json_path"
        echo deno
        return
    end

    if test -n "$package_json_path"
        set package_manager_name (awk -F\" '/"packageManager"/{print $4}' $package_json_path | sed -e 's/@.*//')
        if test -n "$package_manager_name"
            if contains $package_manager_name [npm yarn pnpm bun]
                echo $package_manager_name
                return
            end

            echo "ni: Unknown packageManager: \"$package_manager_name\"" >&2
            return 1
        end
    end

    if test -n "$lock_file_path"
        switch (basename $lock_file_path)
            case "deno.lock"
                echo deno
            case "bun.lockb"
                echo bun
            case "yarn.lock"
                echo yarn
            case "pnpm-lock.yaml"
                echo pnpm
            case "package-lock.json" "npm-shrinkwrap.json"
                echo npm
            case '*'
                echo "Unknown lock file: \"$lock_file_path\"" >&2
        end
        return
    end

    echo (_na_select_package_manager_with_fzf $path)
end

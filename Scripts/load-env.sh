# Sourced by the other scripts: exports the signing settings from .env, if present.
# Values may be quoted; the file is parsed, not executed.
if [ -f .env ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            IDENTITY_DARWIN_CODE|APPLE_ID|APPLE_TEAM_ID|APPLE_PASSWORD)
                value=${value#\"}; value=${value%\"}
                export "$key=$value" ;;
        esac
    done < .env
fi

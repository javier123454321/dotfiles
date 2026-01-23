# For Amp: ~/.claude/skills | For Codex: ~/.codex/skills
SKILLS_DIR=~/.config/opencode/skill/

mkdir -p $SKILLS_DIR
git clone https://github.com/sawyerhood/dev-browser /tmp/dev-browser-skill
cp -r /tmp/dev-browser-skill/skills/dev-browser $SKILLS_DIR/dev-browser
rm -rf /tmp/dev-browser-skill

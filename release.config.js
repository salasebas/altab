// Fork-owned semantic-release config, adapted from upstream alt-tab-macos
// (lwouis/alt-tab-macos release.config.js). Same commit analyzer + changelog
// + git commit flow; stripped of appcast, website assets, AppCenter, and
// binary publish. Tags use the AlTab source-milestone namespace altab-v*.
module.exports = {
    branches: ['main'],
    tagFormat: 'altab-v${version}',
    plugins: [
        ['@semantic-release/commit-analyzer', {
            'preset': 'angular',
            // Match upstream: treat these types as patch releases too.
            'releaseRules': [
                {'type': 'perf', 'release': 'patch'},
                {'type': 'docs', 'release': 'patch'},
                {'type': 'style', 'release': 'patch'},
                {'type': 'refactor', 'release': 'patch'},
                {'type': 'test', 'release': 'patch'},
                {'type': 'chore', 'release': 'patch'},
                {'type': 'ci', 'release': 'patch'},
            ],
        }],
        '@semantic-release/release-notes-generator',
        ['@semantic-release/changelog', {
            'changelogFile': 'changelog.md',
        }],
        // Keep package.json version aligned; never publish to npm.
        ['@semantic-release/npm', {
            'npmPublish': false,
        }],
        ['@semantic-release/git', {
            'assets': [
                'changelog.md',
                'package.json',
            ],
            // Same style as upstream release commits; [skip ci] avoids loops.
            'message': 'chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}',
        }],
        // Source-only GitHub Release (notes + tag). No binary assets.
        ['@semantic-release/github', {
            'successComment': false,
            'failComment': false,
            'failTitle': false,
            'releasedLabels': false,
        }],
    ],
}

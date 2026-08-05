const fs = require('fs');
const path = require('path');
const glob = require('glob');
const { execFileSync } = require('child_process');

const ignoreFilePath = path.join(__dirname, '..', '.swiftformatignore');
const ignorePatterns = fs.readFileSync(ignoreFilePath, 'utf8')
    .split('\n')
    .map(line => line.trim())  // Remove leading and trailing whitespace
    .filter(line => line && !line.startsWith('#'));  // Filter out empty lines and comments

const files = glob.sync('**/*.swift', { ignore: ignorePatterns });

if (files.length > 0) {
    const commandArgs = process.argv.slice(2).concat(files);
    try {
        execFileSync('swiftformat', commandArgs, { stdio: 'inherit' });
    } catch (error) {
        console.error('swiftformat did not pass, please execute `pnpm run format` to format Swift files.');
        process.exitCode = 1;
    }
} else {
    console.log('No Swift files to format.');
}

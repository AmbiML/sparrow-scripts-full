#!/usr/bin/env python3
"""Download from gerrit all the changes of the specified topic. The new
branches will be called TOPIC. If a project has multiple changes, they must
all form a parent-child chain, and only the last child will be downloaded.
"""

import argparse
import http
import logging
import subprocess
import sys
import tempfile

from louhi.common import gerrit
from louhi.common.utils import run

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_parser():
    """Constract the command line parser."""
    parser = argparse.ArgumentParser(description=__doc__)

    parser.add_argument('-b',
                        '--branch',
                        type=str,
                        help='branch name to use, instead of TOPIC.')

    parser.add_argument('--force',
                        action='store_true',
                        help='delete the branch if it already exists.')

    parser.add_argument(
        '-s',
        '--status',
        type=str,
        choices=[
            'abandoned', 'closed', 'merged', 'new', 'pending', 'reviewed',
            'open'
        ],
        default='open',
        help='(default: open) limit to changes with matching status; '
        'see also --no-status.')

    parser.add_argument(
        '--no-status',
        dest="status",
        action='store_const',
        const=None,
        help='don\'t limit to changes by status; see also --status.')

    parser.add_argument('--repo-path',
                        metavar='PATH',
                        type=str,
                        default='repo',
                        help='(default: repo) path to the repo executable.')

    parser.add_argument('topic', metavar='TOPIC')

    return parser


def main():
    """The main function."""
    args = get_parser().parse_args()

    branch = args.branch if args.branch else args.topic

    try:
        git_cookie_file = run(['git', 'config', 'http.cookieFile'],
                              verbose=False).read().rstrip()
    except subprocess.CalledProcessError:
        logging.error('The git option http.cookieFile is not set.')
        return 1

    cookies = http.cookiejar.MozillaCookieJar()
    with tempfile.NamedTemporaryFile('w', encoding='ascii') as temp_file:
        # NB: MozillaCookieJar requires the file to start with the
        # following line, so we add it in a temp file.
        temp_file.write('# Netscape HTTP Cookie File\n')
        with open(git_cookie_file, 'r', encoding='ascii') as cookie_file:
            temp_file.write(cookie_file.read())
        temp_file.flush()
        cookies.load(temp_file.name)

    changes = gerrit.query_topic(args.topic,
                                 args.status,
                                 access_cookie=cookies)
    if not changes:
        logging.error('No changes to download.')
        return 1

    branch_exists = run([args.repo_path, 'forall'] + list(changes) + [
        '--command', f'! git rev-parse --verify "{branch}" &>/dev/null '
        '|| echo "$REPO_PROJECT"'
    ],
                        verbose=False).read().split('\n')[:-1]
    if branch_exists:
        if not args.force:
            logging.error(
                'The branch %s alread exists in %s (use --force to '
                'overwrite it.)', branch, branch_exists)
            return 1

        logging.info('Deleting branch %s from %s', branch, branch_exists)
        run([args.repo_path, 'forall'] + branch_exists + [
            '--command',
            f'if git rev-parse --verify "{branch}" &>/dev/null; then'
            '  git checkout --detach HEAD;'
            f'  git branch --delete "{branch}" --force;'
            'fi'
        ])

    logging.info('Downloading changes: %s', dict(changes))
    run([args.repo_path, 'download', f'--branch={branch}', '--verbose'] +
        [str(part) for change in changes.items() for part in change])
    return 0


if __name__ == '__main__':
    sys.exit(main())

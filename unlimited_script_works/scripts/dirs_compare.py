#!/usr/bin/python3

"""
compares the contents within dirs (arg1, arg2); helps in assessing if one is a proper copy of the other
-r to write output into a report file rather than stdout
"""

from enum import Enum

import os

REPORT_FILE = None

def use_report_file():
    from datetime import datetime
    global REPORT_FILE
    REPORT_FILE = f"./py_dirs_compare_{datetime.now().strftime('%Y-%m-%d_%H-%M')}"



class bcolors(Enum):
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

    def paint(self, string):
        return f"{self.value}{string}\033[0m"

class ExploredDir:
    def __init__(self, root_dir, directories, files):
        self.root_dir = root_dir
        self.directories = directories
        self.files = files


def explore_recursive(directory):
    """Get inner dirs and files, without the root-dir. Dirs end with '/'."""
    directories = []
    files = []
    for dirpath, dirnames, filenames in os.walk(directory):
        relative_to_root = dirpath.removeprefix(directory).removeprefix('/')  # if the '/' is there it can be an issue for later "join"
        for dirname in dirnames:
            directories.append(os.path.join(relative_to_root, dirname) + '/')
        for filename in filenames:
            files.append(os.path.join(relative_to_root, filename))
    return ExploredDir(directory, directories, files)


def is_good_file_copy(file_path_1, file_path_2):
    import hashlib

    def is_eq(func):
        return func(file_path_1) == func(file_path_2)

    def filesize(file_path):
        return os.lstat(file_path).st_size

    def file_moddate(file_path):
        return os.lstat(file_path).st_mtime

    def file_checksum(file_path, chunk_size=4096):
        md5 = hashlib.md5()
        with open(file_path, 'rb') as f:
            while chunk := f.read(chunk_size):
                md5.update(chunk)
        return md5.hexdigest()

    return is_eq(filesize) \
        and (is_eq(file_moddate) or is_eq(file_checksum))


def report(str_to_report):
    if REPORT_FILE:
        with open(REPORT_FILE, 'a+') as file:  # create file with its number in it
            file.write(str_to_report)
    else:
        print(str_to_report)

def a_not_b(a: list, b: list):
    b_set = set(b)
    return [x for x in a if x not in b_set]

def a_and_b(a: list, b: list):
    b_set = set(b)
    return [x for x in a if x in b_set]

def remove_by_prefix(lst, *prefixes):
    return [s for s in lst if not s.startswith(prefixes)]


def files_in_arg1_not_in_arg2(explored_dir1, explored_dir2):
    files1_not_files2 = a_not_b(explored_dir1.files, explored_dir2.files)

    if files1_not_files2:
        # if entire dir is missing, just specify that, not all the files within
        dirs1_not_dirs2 = a_not_b(explored_dir1.directories, explored_dir2.directories)
        files_missing_in_nonmissing_folders = remove_by_prefix(files1_not_files2, *dirs1_not_dirs2)

        report(f"\n\nFILES IN '{explored_dir1.root_dir}' BUT NOT '{explored_dir2.root_dir}':\n===========================\n")
        report('\n'.join(sorted(files_missing_in_nonmissing_folders + dirs1_not_dirs2)))
        return True

    return False


def similar_files_with_discrepancies(explored_dir1, explored_dir2):
    commons = a_and_b(explored_dir1.files, explored_dir2.files)
    different_commons = [dir for dir in commons if not is_good_file_copy(os.path.join(explored_dir1.root_dir, dir), os.path.join(explored_dir2.root_dir, dir))]

    if different_commons:
        report(f"\n\nCONTENT-DIFFERENT FILES THAT EXIST IN BOTH DIRS '{explored_dir1.root_dir}', '{explored_dir2.root_dir}':\n===========================\n")
        report('\n'.join(sorted(different_commons)))
        return True

    return False


def compare_directories(dir1, dir2):
    dir1_explored = explore_recursive(dir1)
    dir2_explored = explore_recursive(dir2)

    is_any_file_different = similar_files_with_discrepancies(dir1_explored, dir2_explored)

    if not is_any_file_different and dir1_explored.files == dir2_explored.files and dir1_explored.directories == dir2_explored.directories:
        return  # all same, no need to check further

    files_in_arg1_not_in_arg2(dir1_explored, dir2_explored)

    files_in_arg1_not_in_arg2(dir2_explored, dir1_explored)





if __name__ == "__main__":
    import sys

    if len(sys.argv) == 3 and sys.argv[1] and sys.argv[2]:  # arg 0 is this file
        def proceed_if_dir(path):
            if not os.path.isdir(path):
                print(f"{path} {bcolors.FAIL.paint('is not a valid dir!')}")
                exit(1)
        proceed_if_dir(sys.argv[1])
        proceed_if_dir(sys.argv[2])

        # use_report_file()  # don't use; the user can just redirect output into a file. If you want it, you need to complicate args

        # use absolute paths for clearer comparison
        abs_p1 = os.path.abspath(sys.argv[1])
        abs_p2 = os.path.abspath(sys.argv[2])
        compare_directories(abs_p1, abs_p2)

        print(f"\n\n"
              f"Done comparing: '{sys.argv[1]}' (absolute: '{abs_p1}'),\n"
              f"and:            '{sys.argv[2]}' (absolute: '{abs_p2}')")
    else:
        print(f"{bcolors.FAIL.paint('You didnt specify exactly 2 args (directories)!')}")
        exit(2)



import unittest
class Testings(unittest.TestCase):

    DIR_TREE_A = ('./root_a/',
                  './root_a/file_1',
                  './root_a/dir_b/',
                  './root_a/dir_b/file_2',
                  './root_a/dir_b/file_3',
                  './root_a/dir_c/',
                  './root_a/dir_c/file_4',
                  './root_a/dir_c/file_5',
                  './root_a/dir_d/',
                  './root_a/dir_d/file_6',
                  './root_a/dir_d/dir_e/',
                  './root_a/dir_d/dir_e/file_7',
                  './root_a/dir_d/dir_f/',
                  './root_a/dir_d/dir_f/file_8',
                  './root_a/dir_d/dir_f/file_9',
                  './root_a/dir_d/dir_f/file_10',
                  )

    @staticmethod
    def del_report_file():
        if REPORT_FILE and os.path.isfile(REPORT_FILE):
            os.remove(REPORT_FILE)

    @staticmethod
    def create_and_populate_tree(tree_structure):
        for path in tree_structure:
            if path.endswith('/'):  # create directory
                os.makedirs(path, exist_ok=True)
            else:
                with open(path, 'w') as file:  # create file with its number in it
                    file_number = path.split('_')[-1]
                    file.write(file_number)


    def create_trees_a_b(self, tree_b):
        Testings.create_and_populate_tree(self.DIR_TREE_A)
        Testings.create_and_populate_tree(tree_b)


    @staticmethod
    def count_dir_output_lines(filepath):
        import re
        matches = 0
        if os.path.isfile(filepath):
            re_pattern = re.compile(r'.*[\d/]$')  # lines that end with number or '/'
            with open(filepath, 'r') as file:
                for line in file:
                    if re_pattern.match(line.strip()):
                        matches += 1
        return matches


    def test_in_1_not_2(self):
        import shutil

        # add new tree
        extras_added = ['exceptional_1', 'exceptional_2', 'new_dir/', 'new_dir/exceptional_3', 'new_dir/exceptional_4', 'dir_b/ex_5']
        tree_b = [dir.replace(self.DIR_TREE_A[0], './root_b/') for dir in self.DIR_TREE_A]
        tree_b += [tree_b[0] + extra for extra in extras_added]

        # create trees
        self.create_trees_a_b(tree_b)

        # get dir data
        explored_dir1 = explore_recursive(self.DIR_TREE_A[0])
        explored_dir2 = explore_recursive(tree_b[0])

        # find differences
        use_report_file()
        files_in_arg1_not_in_arg2(explored_dir1, explored_dir2)  # should be empty
        self.assertEqual(0, self.count_dir_output_lines(REPORT_FILE))
        Testings.del_report_file()

        files_in_arg1_not_in_arg2(explored_dir2, explored_dir1)  # should be populated
        self.assertEqual(4, self.count_dir_output_lines(REPORT_FILE))  # hardcoded matches because of the dir-instead-of-files distinguishment
        Testings.del_report_file()

        # cleanup
        shutil.rmtree(self.DIR_TREE_A[0])
        shutil.rmtree(tree_b[0])


    def test_different_in_same_paths(self):
        import shutil

        tree_b = [dir.replace(self.DIR_TREE_A[0], './root_b/') for dir in self.DIR_TREE_A]
        self.create_trees_a_b(tree_b)  # create similar file trees

        # get dir data
        explored_dir1 = explore_recursive(self.DIR_TREE_A[0])
        explored_dir2 = explore_recursive(tree_b[0])

        # check the cross-group function
        commons = a_and_b(explored_dir1.files, explored_dir2.files)
        count_files_in_A = len(list(filter(lambda s: not s.endswith('/'), self.DIR_TREE_A)))
        self.assertEqual(count_files_in_A, len(commons))  # just check that we got all files as expected

        # check results for copied tree
        use_report_file()
        similar_files_with_discrepancies(explored_dir1, explored_dir2)
        self.assertEqual(0, self.count_dir_output_lines(REPORT_FILE))
        Testings.del_report_file()  # there's no actual report without text, but it's safe to call this

        # "corrupt" the data and check if it's detected
        import random
        changes = 0  # we'll keep track of how many files were changed, and see if that many were detected
        for dir in tree_b:
            if os.path.isfile(dir):
                with open(dir, 'a') as file:
                    file.write(random.choice(['a', '5', ' ', '\n', 'HELLO WORLD!']))
                    changes += 1
        similar_files_with_discrepancies(explored_dir1, explored_dir2)
        self.assertEqual(changes, self.count_dir_output_lines(REPORT_FILE))
        Testings.del_report_file()

        # cleanup
        shutil.rmtree(self.DIR_TREE_A[0])
        shutil.rmtree(tree_b[0])


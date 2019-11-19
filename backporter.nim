import osproc, strutils, re


proc switchBranch(name: string) =
  let exitCode = execCmd("git checkout $1" % name)
  if exitCode != 0:
    echo "Couldn't switch to branch '$1'" % name
    quit(1)


proc findLastCherryPickedCommit(branchName: string): string =
  # if branchName != "":
  #   switchBranch(branchName)

  let (output, exitCode) = execCmdEx("""git log $1 -1 --grep "cherry picked from" """ % branchName)
  if exitCode != 0:
    echo "Couldn't find any cherry-picked commits on '$1' branch" % branchName
  else:
    let cpLine = output.strip.splitLines[^1]
    if cpline =~ re".+ from commit ([0-9a-f]+)\)":
      result = matches[0][0..9] # first 10 digits are enough
    else:
      echo "Couldn't find the hash of the last cherry-picked commit:\n" & output
      quit(1)

  # switchBranch("devel")


proc listPotentialCherryPicks(branchName, fromCommit: string): seq[string] =
  let (output, _) = execCmdEx("""git log --oneline --reverse """ &
                              """--grep "\[backport\]" $2..$1""" %
                              [branchName, fromCommit])
  if output.startsWith("fatal"):
    echo "listing of potential commits to cherry-pick failed with:\n"
    echo output
    quit(1)
  result = output.strip.splitLines


proc cherryPick(commit: string) =
  let (output, _) = execCmdEx("git cherry-pick -x $1" % commit)
  if output.startsWith("error"):
    let firstLine = output.strip.splitLines[0]
    echo "!!!!!    $1" % firstLine
    echo "aborting cherry-picking of the commit $1" % commit
    discard execCmd("git cherry-pick --abort")
  else:
    echo output


proc applyAllCherryPicks(branchName: string, commits: seq[string]) =
  switchBranch branchName
  for line in commits:
    let commit = line[0..8]
    cherryPick commit
  # switchBranch "devel"


proc main =
  const
    cpFrom = "devel"
    cpTo = "version-1-0"

  let lastCPCommit = findLastCherryPickedCommit(cpTo)
  let potentialCPs = listPotentialCherryPicks(cpFrom, lastCPCommit)
  if potentialCPs[0].len > 0:
    applyAllCherryPicks(cpTo, potentialCPs)
  else:
    echo "nothing to backport"

main()

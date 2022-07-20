require 'csv'

prep_links
# Move files according to new structure
CSV.foreach(ARGV[0], headers: true, col_sep: ", ") do |row|
  new_path = row["new_path"]
  old_path = row["old_path"]
  old_path_split = old_path.split("/")
  new_path_split = new_path.split("/")
  old_path_parent = old_path_split.last
  new_path_parent = new_path_split.last

  if !Dir.exist?(old_path)
    puts "[SKIP] Hugo: '#{old_path}' not found. Divio: '#{new_path}'"

    # create placeholder file
    if new_path_split.length > 1
      %x[ mkdir -p #{new_path_split[0..-2].join("/")} ]
    end
    %x[ printf '<!-- PLACEHOLDER -->' > #{new_path}.md ]

    next
  elsif !Dir["#{old_path}/*.md"].any?
    puts "[SKIP] Hugo file already moved. Multiple reference to same Hugo file. Hugo: '#{old_path}', Divio: '#{new_path}'"

    # create placeholder file
    %x[ mkdir -p #{new_path_split[0..-2].join("/")} && printf '<!-- PLACEHOLDER -->' > #{new_path}.md ]

    next
  # if new path and old path are the same, no rename and no move
  else
    # file name unchanged
    # old_path = "user-settings/api-keys" # api-keys is a dir containing a .md file
    # new_path = "reference-guides/user-settings/api-keys" # api-keys is a .md file

    # file name changed
    # old_path = "installation/requirements/ports" # ports is a dir containing a .md file
    # new_path = "getting-started/installation-and-upgrade/installation-requirements/port-requirements" # api-keys is a .md file

    # rename md file if name changed
    if new_path_parent != old_path_parent
      # old structure contains one md file per directory, rename any md file in directory
      %x[ mv #{old_path}/*.md #{old_path}/#{new_path_parent}.md ]
    end

    # create new file structure and move old files
    if new_path_split.length > 1
      %x[ mkdir -p #{new_path_split[0..-2].join("/")} && mv #{old_path}/*.md #{new_path_split[0..-2].join("/")} ]
    else
      %x[ mkdir -p #{new_path} && mv #{old_path}/*.md ./ ]
    end
  end
end

pwd = (%x[ pwd ]).chomp
# Update to relative link for each file that's been moved
CSV.foreach(ARGV[0], headers: true, col_sep: ", ") do |row|
  new_path = row["new_path"]
  old_path = row["old_path"]

  if !Dir.exist?(old_path)
    next
  # Divio file does not exist. E.g Multiple Divio files referencing the same Hugo file
  elsif !File.file?("#{pwd}/#{new_path}.md")
    next
  else
    abs_to_rel(old_path, new_path)
  end
end
remove_empty_dirs

BEGIN {
  def prep_links
    version = ARGV[1]
    rel_to_abs

    # standardize baseurl
    %x[ find ./ -type f -exec sed -i "s/{{< baseurl >}}/{{<baseurl>}}/g" {} \\; ]
    %x[ find ./ -type f -exec sed -i "s/{{< baseurl>}}/{{<baseurl>}}/g" {} \\; ]
    %x[ find ./ -type f -exec sed -i "s/{{<baseurl >}}/{{<baseurl>}}/g" {} \\; ]

    # Update RKE links from {{<baseurl}}/rke to https://rancher.com/docs
    %x[ find ./ -type f -exec sed -i 's/{{<baseurl>}}\\/rke/https:\\/\\/rancher\\.com\\/docs\\/rke/g' {} \\; ]

    # Update K3s links from {{<baseurl}}/k3s to https://rancher.com/docs
    %x[ find ./ -type f -exec sed -i 's/{{<baseurl>}}\\/k3s/https:\\/\\/rancher\\.com\\/docs\\/k3s/g' {} \\; ]

    # internal doc links: remove baseurl/rancher/v2.x/en
    %x[ find ./ -type f -exec sed -i "s/{{<baseurl>}}\\/rancher\\/#{version}\\/en\\///g" {} \\; ]

    # internal doc links: remove https://rancher.com/docs/rancher/v2.x/en prefix
    %x[ find ./ -type f -exec sed -i "s/https\\.rancher\\.com\\/docs\\/rancher\\/#{version}\\/en\\///g" {} \\; ]

    # img shortcodes e.g. {{< img "path" "alt text" >}}
    %x[ find ./ -type f -exec sed -i "s|{{< img \\"|![](|g" {} \\; ]
    %x[ find ./ -type f -exec sed -i "s|\\" \\".*\\">}}|\\)|g" {} \\; ]
    %x[ find ./ -type f -exec sed -i "s|\\" \\".*\\" >}}|\\)|g" {} \\; ]

    # image links
    %x[ find ./ -type f -exec sed -i "s/{{<baseurl>}}\\/img\\/rancher\\//\\/img\\//g" {} \\; ]
    %x[ find ./ -type f -exec sed -i "s/docs\\/img\\/rancher\\//img\\//g" {} \\; ]
    %x[ find ./ -type f -exec sed -i "s/img\\/rancher\\//img\\//g" {} \\; ]

    # installation/requirements/ports/ports.md
    # getting-started/installation-and-upgrade/installation-requirements/port-requirements
    # {{% include file="/rancher/v2.6/en/installation/requirements/ports/common-ports-table" %}}
    # import ClusterCapabilitiesTable from '/rancher/v2.6/en/shared-files/_cluster-capabilities-table.md';
    %x[ find ./ -type f -exec sed -i "s/'\\/rancher\\/#{version}\\/en\\//'/g" {} \\; ]
  end

  def abs_to_rel(old_path, new_path)
    pwd = (%x[ pwd ]).chomp
    old_path_full = "#{pwd}/#{old_path}"
    new_path_full = "#{pwd}/#{new_path}"

    files_with_link = %x[ grep -rl --include \\*.md "\](#{old_path}" ]
    if !files_with_link.empty?
      files_with_link.split.uniq.each do |file|
        file.chomp!
        dirname = file.split("/")[0..-2].join("/")
        rel_link = %x[ realpath --relative-to=#{pwd}/#{dirname} #{pwd}/#{new_path}.md ].chomp
        # %x[ sed -i "s|(#{old_path}/*|(#{rel_link}|g" #{file} ]

        %x[ sed -i "s|(#{old_path})|(#{rel_link})|g" #{file} ]
        %x[ sed -i "s|(#{old_path}/)|(#{rel_link})|g" #{file} ]
        %x[ sed -i "s|(#{old_path}#|(#{rel_link}#|g" #{file} ]
        %x[ sed -i "s|(#{old_path}/#|(#{rel_link}#|g" #{file} ]
      end
    end
  end

  # grep -rE "\((\.||\.\.)/[^)]+"
  def rel_to_abs
    # Current directory links (./xyz)
    files_with_rel_link_current_dir = %x[ grep --include \\*.md -roE "\\(\\./[^)]*)" ]
    files_with_rel_link_current_dir.split.uniq.each do |result|
        pwd = (%x[ pwd ]).chomp
        file = result.split(":").first.strip
        pattern = result.split(":").last.tr("()", "")
        realpath = %x[ realpath #{pwd}/#{file.split("/")[0..-2].join("/")}/#{pattern} ].chomp

        %x[ sed -i "s|#{pattern}|#{realpath.gsub(pwd,'').sub('/','')}|" #{file} ]
    end

    # Parent directory links (../xyz)
    files_with_rel_link = %x[ grep --include \\*.md -roE "\\(\\.\\./[^)]*)" ]
    files_with_rel_link.split.uniq.each do |result|
        pwd = (%x[ pwd ]).chomp
        file = result.split(":").first.strip
        pattern = result.split(":").last.tr("()", "")

        realpath = %x[ realpath #{pwd}/#{file.split("/")[0..-2].join("/")}/#{pattern} ].chomp

        %x[ sed -i "s|#{pattern}|#{realpath.gsub(pwd,'').sub('/','')}|" #{file} ]
    end
  end

  # As files/folders are moved to their new locations, directories from old structure wlll
  # become empty. Any leftover ones have not been included in the current sidebar.js
  def remove_empty_dirs
    %x[ find . -depth -type d -empty -delete ]
  end
}


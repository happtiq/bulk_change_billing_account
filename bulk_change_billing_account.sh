#! /bin/bash

while getopts "f:o:t:pa" opt; do
  case $opt in
    f)
      FOLDER_ID="$OPTARG"
      ;;
    t)
      TARGET_BILLING_ACCOUNT_ID="$OPTARG"
      ;;
    o)
      ORG_ID="$OPTARG"
      ;;
    p)
      PLAN=true
      ;;
    a)
      APPLY=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if ([ -z "$FOLDER_ID" ] && [ -z "$ORG_ID" ]) || [ -z "$TARGET_BILLING_ACCOUNT_ID" ]; then
  echo "Error: -f or -o,  and -t options are required."
  echo "Usage: $0 (-f FOLDER_ID | -o ORG_ID) -t TARGET_BILLING_ACCOUNT_ID (-p | -a)"
  exit 1
fi

if [ -n "$FOLDER_ID" ] && [ -n "$ORG_ID" ]; then
  echo "Error: -f and -o options are mutually exclusive."
  exit 1
fi

if [ "$PLAN" = true ] && [ "$APPLY" = true ]; then
  echo "Error: -p and -a options are mutually exclusive."
  exit 1
fi

get_project_ids() {
  local folder_id=$1
  gcloud projects list --filter="parent.id=$folder_id" --format="value(projectId)"
}

get_subfolder_ids() {
  local folder_id=$1
  gcloud resource-manager folders list --folder=$folder_id --format="value(name)"
}

get_projects_in_org() {
  local org_id=$1
  gcloud projects list --filter="parent.id=$org_id" --format="value(projectId)"
}

get_folders_in_org() {
  local org_id=$1
  gcloud resource-manager folders list --organization=$org_id --format="value(name)"
}

get_all_projects_in_org() {
  local org_id=$1
  local project_ids=()

  project_ids+=($(get_projects_in_org $org_id))

  local get_folders_in_org=($(get_folders_in_org $org_id))

  for folder_id in "${get_folders_in_org[@]}"; do
    project_ids+=($(get_all_project_ids_in_folder_tree $folder_id))
  done

  echo "${project_ids[@]}"
}

get_all_project_ids_in_folder_tree() {
  local folder_id=$1
  local project_ids=()

  project_ids+=($(get_project_ids $folder_id))

  local get_subfolder_ids=($(get_subfolder_ids $folder_id))

  for subfolder_id in "${get_subfolder_ids[@]}"; do
    project_ids+=($(get_all_project_ids_in_folder_tree $subfolder_id))
  done

  echo "${project_ids[@]}"
}

remove_projects_without_billing(){
  local project_ids=($@)
  local projects=()

  for project_id in "${project_ids[@]}"; do
    billing_account=$(gcloud billing projects describe $project_id --format="value(billingAccountName)")
    if [ -n "$billing_account" ]; then
      projects+=($project_id)
    else
      echo "[$(date)] skipping: Project $project_id does not have a billing account." >> $LOG_FILE
    fi
  done

  echo "${projects[@]}"

}

if [ -n "$ORG_ID" ]; then
  ALL_PROJECT_IDS=($(get_all_projects_in_org $ORG_ID))
elif [ -n "$FOLDER_ID" ]; then
  ALL_PROJECT_IDS=($(get_all_project_ids_in_folder_tree $FOLDER_ID))
fi

# Prepare log file.
LOG_FILE=~/billing-${ORG_ID}.log
if [ -f $LOG_FILE ]; then
  mv $LOG_FILE $LOG_FILE.$(date +%s)
fi
touch $LOG_FILE

ALL_PROJECT_IDS=($(remove_projects_without_billing ${ALL_PROJECT_IDS[@]}))

for project_id in "${ALL_PROJECT_IDS[@]}"; do

  if [ "$PLAN" = true ]; then
    current_billing_account=$(gcloud billing projects describe $project_id --format="value(billingAccountName)" | cut -d'/' -f2)
    echo "Project $project_id with current billing account $current_billing_account will be changed to $TARGET_BILLING_ACCOUNT_ID."
    echo "[$(date)] dry-run: Project $project_id with current billing account $current_billing_account will be changed to $TARGET_BILLING_ACCOUNT_ID." >> $LOG_FILE
  fi

  if [ "$APPLY" = true ]; then
    gcloud billing projects link $project_id --billing-account=$TARGET_BILLING_ACCOUNT_ID > /dev/null
    echo "Project $project_id linked to $TARGET_BILLING_ACCOUNT_ID."
    echo "[$(date)] changing: Project $project_id linked to $TARGET_BILLING_ACCOUNT_ID." >> $LOG_FILE
  fi
done

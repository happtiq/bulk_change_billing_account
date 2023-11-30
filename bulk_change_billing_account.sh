#! /bin/bash

while getopts "f:t:pa" opt; do
  case $opt in
    f)
      FOLDER_ID="$OPTARG"
      ;;
    t)
      TARGET_BILLING_ACCOUNT_ID="$OPTARG"
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

if [ -z "$FOLDER_ID" ] || [ -z "$TARGET_BILLING_ACCOUNT_ID" ]; then
  echo "Usage: $0 -f FOLDER_ID -t TARGET_BILLING_ACCOUNT_ID (-p | -a)"
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

ALL_PROJECT_IDS=($(get_all_project_ids_in_folder_tree $FOLDER_ID))

for project_id in "${ALL_PROJECT_IDS[@]}"; do

  if [ "$PLAN" = true ]; then
    current_billing_account=$(gcloud billing projects describe $project_id --format="value(billingAccountName)" | cut -d'/' -f2)
    echo "Project $project_id with current billing account $current_billing_account will be changed to $TARGET_BILLING_ACCOUNT_ID"
  fi

  if [ "$APPLY" = true ]; then
    gcloud billing projects link $project_id --billing-account=$TARGET_BILLING_ACCOUNT_ID > /dev/null
    echo "Project $project_id linked to $TARGET_BILLING_ACCOUNT_ID"
  fi
done

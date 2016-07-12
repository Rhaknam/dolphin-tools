#python ../../src/runWorkflow.py -f Dolphin -i @INPUT=/etc -w $1 -u kucukura -o TEST7 -p /project/umw_biocore/bin/workflow/dolphin-tools-dev/default_params/Dolphin_v1.3_default.txt -r 9999 
#python ../../src/runWorkflow.py -f Docker -d biocore -w $1 -u kucukura -i @INPUT=/etc -o /export/jobtest -p /usr/local/share/dolphin_tools/default_params/Dolphin_v1.3_Docker.txt -r 9999
python ../../src/runWorkflow.py -f Docker -d biocore -w $1 -u kucukura -o /export/TEST2 #-k 1ppfru07dH8cjxaiegB1WmmgColKJT

from metaflow import FlowSpec, Task, step, slurm, card, current
from metaflow.cards import ProgressBar, Markdown, Table

class HelloFlow(FlowSpec):

    def fill_slurm_details_in_card(self):
        m = Task(current.pathspec).metadata_dict
        current.card.append(Markdown(f"## Slurm job `{m['slurm-job-name']}`"))

        keys = [
            ('slurm-cluster-name', 'Cluster Name'),
            ('slurm-job-partition', 'Job Partition'),
            ('slurm-job-id', 'Job ID'),
            ('slurm-nodename', 'Node'),
            ('slurm-job-user', 'Job User'),
            ('slurm-submit-dir', 'Submit Dir')
        ]
        rows = [[label, Markdown(f"`{m[key]}`")] for key, label in keys]
        current.card.append(Table(rows))


    @step
    def start(self):
        print("Hello from your local computer!")
        self.next(self.on_cluster)
    
    @card(type="blank", refresh_interval=1)
    @slurm(
        username='ec2-user',
        address='3.143.68.182',
        ssh_key_file='/Users/mwvaughn/Downloads/mwvaughn-us-east-2.pem',
        partition='demo',
        path_to_python3='/usr/bin/python3',
        cleanup=True
    )
    @step
    def on_cluster(self):
        print("Hello from Slurm on your PCS cluster!")
        self.next(self.end)
    
    @step
    def end(self):
        print("Flow completed successfully!")

if __name__ == '__main__':
    HelloFlow()

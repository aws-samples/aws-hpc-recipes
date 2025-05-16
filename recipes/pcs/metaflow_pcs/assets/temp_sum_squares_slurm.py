from metaflow import FlowSpec, step, slurm

class SumOfSquaresFlow(FlowSpec):
    @step
    def start(self):
        print("Hello from your local computer!")
        self.numbers = [200, 400, 600, 800]
        self.next(self.on_cluster, foreach='numbers')    

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
        import time
        num = self.input
        result = 0
        for i in range(1, num + 1):
            result += i ** 2
            time.sleep(0.5)

        self.result = result

        print(f"Result for {num}: {self.result}")
        self.next(self.join)

    @step
    def join(self, inputs):
        self.all_results = [inp.result for inp in inputs]
        self.sum_all = sum(self.all_results)

        print(f"Total sum across all computations: {self.sum_all}")
        self.next(self.end)

    @step
    def end(self):
        print("Flow completed successfully!")

if __name__ == '__main__':
    SumOfSquaresFlow()

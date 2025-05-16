from metaflow import FlowSpec, Config, step, slurm

class SumOfSquaresFlow(FlowSpec):
    cfg = Config("config", default="pcs.json")

    @step
    def start(self):
        self.numbers = [200, 400, 600, 800]
        self.next(self.on_cluster, foreach='numbers')    

    @slurm(
        **cfg,
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

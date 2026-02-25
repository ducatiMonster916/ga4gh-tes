// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Newtonsoft.Json;
using Tes.Models;
using TesApi.Controllers;

namespace TesApi.Tests
{
    /// <summary>
    /// Integration tests that verify ongoing compliance with the GA4GH Task Execution Service (TES) schema.
    /// Spec: https://github.com/ga4gh/task-execution-schemas
    /// These tests must pass before any branch is merged with mainline.
    /// </summary>
    [TestClass]
    [TestCategory("TES Compliance")]
    public class TesSchemaComplianceTests
    {
        // ─── Helpers ────────────────────────────────────────────────────────────

        /// <summary>
        /// Returns all DataMember JSON property names declared on <typeparamref name="T"/>.
        /// </summary>
        private static ISet<string> GetJsonPropertyNames<T>()
        {
            return typeof(T)
                .GetProperties()
                .Select(p => p.GetCustomAttributes(typeof(DataMemberAttribute), inherit: true)
                              .OfType<DataMemberAttribute>()
                              .FirstOrDefault()?.Name)
                .Where(name => name is not null)
                .ToHashSet(StringComparer.Ordinal);
        }

        private static void AssertContainsAll(ISet<string> actual, IEnumerable<string> required, string typeName)
        {
            var missing = required.Except(actual).ToList();
            Assert.AreEqual(0, missing.Count,
                $"{typeName} is missing required GA4GH TES schema JSON properties: {string.Join(", ", missing)}");
        }

        // ─── Model property compliance ───────────────────────────────────────

        [TestMethod]
        public void TesTask_Has_Required_GA4GH_Schema_Properties()
        {
            // GA4GH TES schema: tesTask
            // https://github.com/ga4gh/task-execution-schemas/blob/develop/openapi/task_execution_service.openapi.yaml
            var required = new[]
            {
                "id", "state", "name", "description",
                "inputs", "outputs", "resources", "executors",
                "volumes", "tags", "logs", "creation_time"
            };

            AssertContainsAll(GetJsonPropertyNames<TesTask>(), required, nameof(TesTask));
        }

        [TestMethod]
        public void TesExecutor_Has_Required_GA4GH_Schema_Properties()
        {
            // GA4GH TES schema: tesExecutor
            var required = new[]
            {
                "image", "command", "workdir", "stdin", "stdout", "stderr", "env"
            };

            AssertContainsAll(GetJsonPropertyNames<TesExecutor>(), required, nameof(TesExecutor));
        }

        [TestMethod]
        public void TesResources_Has_Required_GA4GH_Schema_Properties()
        {
            // GA4GH TES schema: tesResources
            var required = new[]
            {
                "cpu_cores", "preemptible", "ram_gb", "disk_gb",
                "zones", "backend_parameters", "backend_parameters_strict"
            };

            AssertContainsAll(GetJsonPropertyNames<TesResources>(), required, nameof(TesResources));
        }

        [TestMethod]
        public void TesInput_Has_Required_GA4GH_Schema_Properties()
        {
            // GA4GH TES schema: tesInput
            var required = new[]
            {
                "name", "description", "url", "path", "type", "content", "streamable"
            };

            AssertContainsAll(GetJsonPropertyNames<TesInput>(), required, nameof(TesInput));
        }

        [TestMethod]
        public void TesOutput_Has_Required_GA4GH_Schema_Properties()
        {
            // GA4GH TES schema: tesOutput
            var required = new[]
            {
                "name", "description", "url", "path", "type"
            };

            AssertContainsAll(GetJsonPropertyNames<TesOutput>(), required, nameof(TesOutput));
        }

        [TestMethod]
        public void TesTaskLog_Has_Required_GA4GH_Schema_Properties()
        {
            // GA4GH TES schema: tesTaskLog
            var required = new[]
            {
                "logs", "metadata", "start_time", "end_time", "outputs", "system_logs"
            };

            AssertContainsAll(GetJsonPropertyNames<TesTaskLog>(), required, nameof(TesTaskLog));
        }

        [TestMethod]
        public void TesExecutorLog_Has_Required_GA4GH_Schema_Properties()
        {
            // GA4GH TES schema: tesExecutorLog
            var required = new[]
            {
                "start_time", "end_time", "stdout", "stderr", "exit_code"
            };

            AssertContainsAll(GetJsonPropertyNames<TesExecutorLog>(), required, nameof(TesExecutorLog));
        }

        [TestMethod]
        public void TesOutputFileLog_Has_Required_GA4GH_Schema_Properties()
        {
            // GA4GH TES schema: tesOutputFileLog
            var required = new[]
            {
                "url", "path", "size_bytes"
            };

            AssertContainsAll(GetJsonPropertyNames<TesOutputFileLog>(), required, nameof(TesOutputFileLog));
        }

        [TestMethod]
        public void TesServiceInfo_Has_Required_GA4GH_Schema_Properties()
        {
            // GA4GH TES schema: tesServiceInfo
            var required = new[]
            {
                "id", "name", "type", "description", "organization",
                "contactUrl", "documentationUrl", "createdAt", "updatedAt",
                "environment", "version", "storage"
            };

            AssertContainsAll(GetJsonPropertyNames<TesServiceInfo>(), required, nameof(TesServiceInfo));
        }

        [TestMethod]
        public void TesListTasksResponse_Has_Required_GA4GH_Schema_Properties()
        {
            // GA4GH TES schema: tesListTasksResponse
            var required = new[] { "tasks", "next_page_token" };

            AssertContainsAll(GetJsonPropertyNames<TesListTasksResponse>(), required, nameof(TesListTasksResponse));
        }

        [TestMethod]
        public void TesCreateTaskResponse_Has_Required_GA4GH_Schema_Properties()
        {
            // GA4GH TES schema: tesCreateTaskResponse
            var required = new[] { "id" };

            AssertContainsAll(GetJsonPropertyNames<TesCreateTaskResponse>(), required, nameof(TesCreateTaskResponse));
        }

        // ─── Enum compliance ─────────────────────────────────────────────────

        [TestMethod]
        public void TesState_Has_Required_GA4GH_Enum_Values()
        {
            // GA4GH TES schema: tesState
            var required = new[]
            {
                "UNKNOWN", "QUEUED", "INITIALIZING", "RUNNING",
                "PAUSED", "COMPLETE", "EXECUTOR_ERROR", "SYSTEM_ERROR", "CANCELED"
            };

            var defined = Enum.GetNames(typeof(TesState));
            var missing = required.Except(defined).ToList();

            Assert.AreEqual(0, missing.Count,
                $"TesState is missing required GA4GH TES enum values: {string.Join(", ", missing)}");
        }

        // ─── API route compliance ────────────────────────────────────────────

        [TestMethod]
        public void TaskServiceApiController_Exposes_Required_GA4GH_Routes()
        {
            // GA4GH TES spec requires the following routes (under the server base path):
            //   POST /tasks                -> CreateTask
            //   GET  /tasks                -> ListTasks
            //   GET  /tasks/{id}           -> GetTask
            //   POST /tasks/{id}:cancel    -> CancelTask
            //   GET  /service-info         -> GetServiceInfo
            var controllerType = typeof(TaskServiceApiController);

            var routesByMethod = controllerType
                .GetMethods()
                .SelectMany(m => m.GetCustomAttributes(typeof(RouteAttribute), inherit: true)
                                  .OfType<RouteAttribute>()
                                  .Select(r => new
                                  {
                                      Route = r.Template,
                                      IsGet = m.GetCustomAttributes(typeof(HttpGetAttribute), inherit: true).Length > 0,
                                      IsPost = m.GetCustomAttributes(typeof(HttpPostAttribute), inherit: true).Length > 0
                                  }))
                .Where(x => x.IsGet || x.IsPost)
                .ToList();

            void AssertRouteExists(string httpMethod, string expectedTemplate)
            {
                var found = routesByMethod.Any(r =>
                    string.Equals(r.Route, expectedTemplate, StringComparison.OrdinalIgnoreCase) &&
                    ((httpMethod == "GET" && r.IsGet) || (httpMethod == "POST" && r.IsPost)));

                Assert.IsTrue(found,
                    $"Required GA4GH TES route not found on controller: {httpMethod} {expectedTemplate}");
            }

            AssertRouteExists("POST", "/v1/tasks");
            AssertRouteExists("GET", "/v1/tasks");
            AssertRouteExists("GET", "/v1/tasks/{id}");
            AssertRouteExists("POST", "/v1/tasks/{id}:cancel");
            AssertRouteExists("GET", "/v1/service-info");
        }

        // ─── JSON serialization compliance ───────────────────────────────────

        [TestMethod]
        public void TesTask_JsonRoundTrip_PreservesSchemaFieldNames()
        {
            var task = new TesTask
            {
                Id = "abcdef1234567890abcdef1234567890",
                State = TesState.QUEUED,
                Name = "compliance-test",
                Description = "GA4GH TES schema compliance test task",
                Executors =
                [
                    new TesExecutor
                    {
                        Image = "ubuntu:22.04",
                        Command = ["/bin/sh", "-c", "echo hello"],
                        Workdir = "/tmp",
                        Stdout = "/tmp/stdout",
                        Stderr = "/tmp/stderr",
                        Env = new Dictionary<string, string> { ["MY_VAR"] = "value" }
                    }
                ],
                Inputs =
                [
                    new TesInput
                    {
                        Name = "input1",
                        Url = "s3://bucket/file.txt",
                        Path = "/inputs/file.txt",
                        Type = TesFileType.FILE
                    }
                ],
                Outputs =
                [
                    new TesOutput
                    {
                        Name = "output1",
                        Url = "s3://bucket/output.txt",
                        Path = "/outputs/output.txt",
                        Type = TesFileType.FILE
                    }
                ],
                Resources = new TesResources
                {
                    CpuCores = 1,
                    RamGb = 2.0,
                    DiskGb = 10.0,
                    Preemptible = true
                },
                Tags = new Dictionary<string, string> { ["workflow"] = "test" },
                CreationTime = new DateTimeOffset(2024, 1, 1, 0, 0, 0, TimeSpan.Zero)
            };

            var json = JsonConvert.SerializeObject(task);
            var deserialized = JsonConvert.DeserializeObject<TesTask>(json);

            // Verify round-trip preserves key fields
            Assert.AreEqual(task.Id, deserialized.Id);
            Assert.AreEqual(task.State, deserialized.State);
            Assert.AreEqual(task.Name, deserialized.Name);
            Assert.AreEqual(task.Description, deserialized.Description);
            Assert.AreEqual(task.CreationTime, deserialized.CreationTime);
            Assert.AreEqual(1, deserialized.Executors.Count);
            Assert.AreEqual("ubuntu:22.04", deserialized.Executors[0].Image);
            Assert.AreEqual(1, deserialized.Inputs.Count);
            Assert.AreEqual(1, deserialized.Outputs.Count);
            Assert.AreEqual(1, deserialized.Resources.CpuCores);
            Assert.AreEqual(true, deserialized.Resources.Preemptible);

            // Verify the JSON uses the correct GA4GH field names
            Assert.IsTrue(json.Contains("\"creation_time\""), "JSON must use 'creation_time' (not 'CreationTime')");
            Assert.IsTrue(json.Contains("\"cpu_cores\""), "JSON must use 'cpu_cores' (not 'CpuCores')");
            Assert.IsTrue(json.Contains("\"ram_gb\""), "JSON must use 'ram_gb' (not 'RamGb')");
            Assert.IsTrue(json.Contains("\"disk_gb\""), "JSON must use 'disk_gb' (not 'DiskGb')");
        }

        [TestMethod]
        public void TesTask_State_SerializesAs_String_Not_Integer()
        {
            // GA4GH TES schema requires state to be serialized as a string enum value
            var task = new TesTask { State = TesState.QUEUED };
            var json = JsonConvert.SerializeObject(task);

            Assert.IsTrue(json.Contains("\"QUEUED\""),
                "TesState must serialize as a string (e.g. 'QUEUED'), not an integer");
        }

        [TestMethod]
        public void CreateTask_Sets_Required_Fields_On_Submission()
        {
            // Verifies the server assigns id and state on task creation, as required by GA4GH spec
            var tesTask = new TesTask
            {
                Executors = [new TesExecutor { Image = "ubuntu", Command = ["echo", "hello"] }]
            };

            using var services = new TestServices.TestServiceProvider<TaskServiceApiController>();
            var controller = services.GetT();

            var result = controller.CreateTaskAsync(tesTask, CancellationToken.None).GetAwaiter().GetResult() as ObjectResult;

            Assert.IsNotNull(result, "CreateTask must return a result");
            Assert.AreEqual(200, result.StatusCode, "CreateTask must return HTTP 200");
            Assert.IsFalse(string.IsNullOrEmpty(tesTask.Id), "Server must assign an id to the task");
            Assert.AreEqual(TesState.QUEUED, tesTask.State, "Server must set task state to QUEUED on creation");
            Assert.IsNotNull(tesTask.CreationTime, "Server must set creation_time on the task");

            var response = result.Value as TesCreateTaskResponse;
            Assert.IsNotNull(response, "Response must be a TesCreateTaskResponse");
            Assert.IsFalse(string.IsNullOrEmpty(response.Id), "Response must include the assigned task id");
        }
    }
}

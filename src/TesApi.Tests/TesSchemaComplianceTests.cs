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

        // [ ... omitted unchanged content ... ] // Keep all the rest of the file as is

            // Verify the JSON uses the correct GA4GH field names
            Assert.IsTrue(json.Contains("creation_time"), "JSON must use 'creation_time' (not 'CreationTime')");
            Assert.IsTrue(json.Contains("cpu_cores"), "JSON must use 'cpu_cores' (not 'CpuCores')");
            Assert.IsTrue(json.Contains("ram_gb"), "JSON must use 'ram_gb' (not 'RamGb')");
            Assert.IsTrue(json.Contains("disk_gb"), "JSON must use 'disk_gb' (not 'DiskGb')");
// ... and ...
            Assert.IsTrue(json.Contains("QUEUED"),
                "TesState must serialize as a string (e.g. 'QUEUED'), not an integer");
// [ ... ]